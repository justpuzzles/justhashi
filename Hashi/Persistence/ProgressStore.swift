import Foundation
import Observation

/// The two save slots. A standard game and a daily each keep their own, so
/// starting one never overwrites the other (1.1 had a single shared slot).
enum GameSlot: String, Hashable, Sendable, CaseIterable {
    case standard
    case daily

    init(dailyKey: DayKey?) {
        self = dailyKey == nil ? .standard : .daily
    }
}

/// What opening a Daily does with the daily save slot.
enum DailyOpening: Equatable {
    /// The slot holds this day, unfinished: carry on with it.
    case resume
    /// Nothing worth keeping is in the way.
    case fresh
    /// Another day's unfinished Daily is in the slot.
    case replacing(DayKey)
}

/// The result of recording a solve, for the win card.
struct SolveResult: Equatable {
    /// False for a daily that was already solved: nothing was recorded.
    var counted: Bool
    var newBestTime: Bool
    /// For a replayed daily, the time of the first solve.
    var firstDailyTime: TimeInterval?
}

/// All persisted progress: settings, best times, stats, mastery, the daily
/// streak, and the in-progress games. UserDefaults + Codable, versioned keys.
@Observable @MainActor
final class ProgressStore {
    private let defaults: UserDefaults

    private enum Key {
        static let bestTimes = "hashi.bestTimes.v1"
        /// The 1.1 single slot. Kept as the standard slot's key, so a saved
        /// game survives the update and a downgrade still finds it.
        static let saveGame = "hashi.saveGame.v1"
        static let saveGameDaily = "hashi.saveGame.daily.v1"
        static let stats = "hashi.stats.v1"
        static let mastery = "hashi.mastery.v1"
        static let settings = "hashi.settings.v1"
        static let lastPlayed = "hashi.lastPlayed.v1"
        static let daily = "hashi.daily.v1"
    }

    /// The size/difficulty the player last started a game with, so the pickers
    /// come back where they left them and the cache can warm the right key.
    struct GameChoice: Codable, Hashable {
        let size: BoardSize
        let difficulty: Difficulty
    }

    struct Settings: Codable, Equatable {
        var hapticsEnabled = true
        var showErrors = true
        /// Auto-complete islands the first two techniques force. Off by
        /// default — drawing bridges is the game.
        var autoCompleteForced = false
        /// Show remaining capacity instead of the clue (expert mode).
        var showRemainingCount = false
    }

    struct Stats: Codable, Equatable {
        var puzzlesSolved = 0
        var totalPlayTime: TimeInterval = 0
        var solvedBySize: [BoardSize: Int] = [:]
        var solvedByDifficulty: [Difficulty: Int] = [:]
    }

    struct BestTimeKey: Hashable, Codable {
        let size: BoardSize
        let difficulty: Difficulty
    }

    private(set) var bestTimes: [BestTimeKey: TimeInterval] = [:]
    private(set) var stats = Stats()
    /// The saved games, one per slot. Observable state rather than re-read on
    /// demand so the Continue card appears the moment a game is saved —
    /// reading UserDefaults inside a view body never invalidates it.
    private let saves: SaveSlots<GameSlot, HashiGame.Snapshot>
    private(set) var lastPlayed: GameChoice?
    private(set) var daily = DailyRecord()
    var settings = Settings() {
        didSet { save(settings, key: Key.settings) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        saves = SaveSlots(defaults: userDefaults,
                          keys: [.standard: Key.saveGame, .daily: Key.saveGameDaily])
        bestTimes = load([BestTimeKey: TimeInterval].self, key: Key.bestTimes) ?? [:]
        stats = load(Stats.self, key: Key.stats) ?? Stats()
        settings = load(Settings.self, key: Key.settings) ?? Settings()
        lastPlayed = load(GameChoice.self, key: Key.lastPlayed)
        daily = load(DailyRecord.self, key: Key.daily) ?? DailyRecord()
        // 1.1 kept a daily in the one slot there was. Move it to its own, or
        // it would show as the standard Continue game and be overwritten by
        // the next standard game.
        if saves[.standard]?.dailyKey != nil {
            saves.move(from: .standard, to: .daily)
        }
    }

    /// Records the *requested* size/difficulty for a new game.
    func recordLastPlayed(size: BoardSize, difficulty: Difficulty) {
        let choice = GameChoice(size: size, difficulty: difficulty)
        guard choice != lastPlayed else { return }
        lastPlayed = choice
        save(choice, key: Key.lastPlayed)
    }

    // MARK: - Best times / stats

    func bestTime(size: BoardSize, difficulty: Difficulty) -> TimeInterval? {
        bestTimes[BestTimeKey(size: size, difficulty: difficulty)]
    }

    /// Records a solve; returns true when it's a new best time. Counts
    /// unconditionally: a game that may be a replayed daily goes through
    /// `recordWin` instead.
    @discardableResult
    func recordSolve(size: BoardSize, difficulty: Difficulty, time: TimeInterval) -> Bool {
        stats.puzzlesSolved += 1
        stats.totalPlayTime += time
        stats.solvedBySize[size, default: 0] += 1
        stats.solvedByDifficulty[difficulty, default: 0] += 1
        save(stats, key: Key.stats)

        let key = BestTimeKey(size: size, difficulty: difficulty)
        let isRecord = bestTimes[key].map { time < $0 } ?? true
        if isRecord {
            bestTimes[key] = time
            save(bestTimes, key: Key.bestTimes)
        }
        return isRecord
    }

    /// Everything a won game records, in one place: the daily first (so the
    /// win card's streak reads the new record on its first frame), then stats
    /// and best times, unless the daily was already solved. A replay keeps its
    /// first time and must not count as another solve or set a best time.
    func recordWin(size: BoardSize, difficulty: Difficulty, time: TimeInterval,
                   daily day: DayKey?) -> SolveResult {
        if let day, case .replay(let first) = recordDailyCompleted(day: day, time: time) {
            return SolveResult(counted: false, newBestTime: false, firstDailyTime: first)
        }
        let best = recordSolve(size: size, difficulty: difficulty, time: time)
        return SolveResult(counted: true, newBestTime: best, firstDailyTime: nil)
    }

    // MARK: - Daily streak (PuzzleKit's DailyRecord, under the 1.1 key)

    func hasCompletedDaily(_ day: DayKey) -> Bool {
        daily.hasCompleted(day)
    }

    func dailyTime(_ day: DayKey) -> TimeInterval? {
        daily.time(for: day)
    }

    /// Whether today's streak is at risk (streak alive, today not yet done).
    /// Computed, never stored — storage would go stale at midnight.
    func streakIsAtRisk(today: DayKey) -> Bool {
        daily.isAtRisk(today: today)
    }

    /// The streak to *show*: 0 when the chain is already broken (yesterday
    /// missed), even before today is played.
    func displayStreak(today: DayKey) -> Int {
        daily.displayStreak(today: today)
    }

    /// Records a completed daily. Idempotent per day (a replay records
    /// nothing); an older daily finished late keeps its time and leaves the
    /// streak alone.
    @discardableResult
    func recordDailyCompleted(day: DayKey, time: TimeInterval) -> DailyOutcome {
        let outcome = daily.record(day: day, time: time)
        if !outcome.isReplay {
            save(daily, key: Key.daily)
        }
        return outcome
    }

    // MARK: - Save game

    /// How opening `day`'s Daily should go. The daily slot holds one game, so
    /// a different unfinished Daily in it is replaced by the new board's
    /// first move: the caller asks first.
    func openDaily(_ day: DayKey) -> DailyOpening {
        guard let saved = savedGame(.daily)?.dailyKey, !hasCompletedDaily(saved) else {
            return .fresh
        }
        // A replayed Daily takes the slot too, so it asks as well.
        return saved == day ? .resume : .replacing(saved)
    }

    func savedGame(_ slot: GameSlot) -> HashiGame.Snapshot? {
        saves[slot]
    }

    /// Saves into the snapshot's own slot. `hasProgress: false` (a board the
    /// player has not touched) keeps whatever that slot already holds.
    func saveGame(_ snapshot: HashiGame.Snapshot, hasProgress: Bool = true) {
        saves.save(snapshot, in: snapshot.slot, hasProgress: hasProgress)
    }

    func clearSavedGame(_ slot: GameSlot) {
        saves.clear(slot)
    }

    // MARK: - Mastery (used by MasteryTracker)

    func loadMastery<T: Decodable>(_ type: T.Type) -> T? {
        load(type, key: Key.mastery)
    }

    func saveMastery(_ value: some Encodable) {
        save(value, key: Key.mastery)
    }

    // MARK: - Codable plumbing

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save(_ value: some Encodable, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
