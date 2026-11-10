import Foundation
import Testing
@testable import Hashi

/// 1.2: a standard game and a Daily keep separate saves (PuzzleKit's
/// SaveSlots), a replayed Daily counts nothing, and opening a Daily never
/// silently replaces another unfinished one.
@Suite("Save slots and daily records")
@MainActor
struct SaveSlotsTests {
    private let monday = DayKey(year: 2026, month: 11, day: 9)
    private let tuesday = DayKey(year: 2026, month: 11, day: 10)

    private func freshDefaults() -> (UserDefaults, String) {
        let name = "hashi-slots-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    private func game(_ puzzle: HashiPuzzle = Fixtures.square, daily: DayKey? = nil,
                      moved: Bool = true) -> HashiGame {
        let generated = GeneratedHashiPuzzle(puzzle: puzzle, difficulty: .easy,
                                             techniqueProfile: [:])
        let game = HashiGame(puzzle: generated, requestedDifficulty: .easy, dailyKey: daily)
        if moved { game.cycleBridge(edge: 0) }
        return game
    }

    @Test func dailyAndStandardNeverOverwriteEachOther() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ProgressStore(userDefaults: defaults)
        let standard = game(Fixtures.square)
        let daily = game(Fixtures.crossing, daily: tuesday)
        store.saveGame(standard.snapshot)
        store.saveGame(daily.snapshot)
        #expect(store.savedGame(.standard)?.generated == standard.generated)
        #expect(store.savedGame(.daily)?.dailyKey == tuesday)

        let relaunched = ProgressStore(userDefaults: defaults)
        #expect(relaunched.savedGame(.standard)?.dailyKey == nil)
        #expect(relaunched.savedGame(.daily)?.generated == daily.generated)

        // Winning the daily clears only its own slot.
        relaunched.clearSavedGame(daily.slot)
        #expect(relaunched.savedGame(.daily) == nil)
        #expect(relaunched.savedGame(.standard) != nil)
    }

    /// 1.1 had one slot, under the key the standard slot keeps. A Daily left
    /// in it moves to the daily slot on the first 1.2 launch.
    @Test func a1_1DailyMovesToTheDailySlot() throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let old = game(Fixtures.crossing, daily: monday)
        defaults.set(try JSONEncoder().encode(old.snapshot), forKey: "hashi.saveGame.v1")

        let store = ProgressStore(userDefaults: defaults)
        #expect(store.savedGame(.standard) == nil)
        #expect(store.savedGame(.daily)?.dailyKey == monday)
        #expect(store.savedGame(.daily)?.board == old.board)
    }

    @Test func a1_1StandardGameStaysWhereItIs() throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let old = game(Fixtures.square)
        defaults.set(try JSONEncoder().encode(old.snapshot), forKey: "hashi.saveGame.v1")

        let store = ProgressStore(userDefaults: defaults)
        #expect(store.savedGame(.standard)?.board == old.board)
        #expect(store.savedGame(.daily) == nil)
    }

    /// Play, look, back out: the untouched board must not replace Continue.
    @Test func anUntouchedBoardKeepsTheSlot() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ProgressStore(userDefaults: defaults)
        let kept = game(Fixtures.square)
        store.saveGame(kept.snapshot)
        let glance = game(Fixtures.crossing, moved: false)
        store.saveGame(glance.snapshot, hasProgress: glance.hasMoves)
        #expect(store.savedGame(.standard)?.generated == kept.generated)
    }

    /// The 1.1 streak record decodes into PuzzleKit's DailyRecord unchanged.
    @Test func a1_1DailyRecordStillReads() throws {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let json = #"{"lastCompleted":{"year":2026,"month":11,"day":9},"currentStreak":4,"bestStreak":7,"completedTimes":{"2026-11-09":123.5}}"#
        defaults.set(Data(json.utf8), forKey: "hashi.daily.v1")

        let store = ProgressStore(userDefaults: defaults)
        #expect(store.daily.currentStreak == 4)
        #expect(store.daily.bestStreak == 7)
        #expect(store.dailyTime(monday) == 123.5)
        #expect(store.displayStreak(today: tuesday) == 4)
        #expect(store.streakIsAtRisk(today: tuesday))
    }

    @Test func aReplayedDailyCountsNothing() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ProgressStore(userDefaults: defaults)
        let first = store.recordWin(size: .small, difficulty: .easy, time: 200, daily: monday)
        #expect(first == SolveResult(counted: true, newBestTime: true, firstDailyTime: nil))

        let replay = store.recordWin(size: .small, difficulty: .easy, time: 90, daily: monday)
        #expect(replay == SolveResult(counted: false, newBestTime: false, firstDailyTime: 200))
        #expect(store.stats.puzzlesSolved == 1)
        #expect(store.stats.totalPlayTime == 200)
        #expect(store.bestTime(size: .small, difficulty: .easy) == 200)
        #expect(store.dailyTime(monday) == 200)
    }

    @Test func aStandardWinAlwaysCounts() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ProgressStore(userDefaults: defaults)
        _ = store.recordWin(size: .small, difficulty: .easy, time: 200, daily: nil)
        let second = store.recordWin(size: .small, difficulty: .easy, time: 150, daily: nil)
        #expect(second.counted && second.newBestTime)
        #expect(store.stats.puzzlesSolved == 2)
    }

    @Test func openingADailyResumesStartsFreshOrAsks() {
        let (defaults, name) = freshDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ProgressStore(userDefaults: defaults)
        // Nothing saved.
        #expect(store.openDaily(tuesday) == .fresh)

        // Monday's daily half done.
        store.saveGame(game(Fixtures.crossing, daily: monday).snapshot)
        #expect(store.openDaily(monday) == .resume)
        #expect(store.openDaily(tuesday) == .replacing(monday))

        // A standard game in progress is no reason to ask.
        store.saveGame(game(Fixtures.square).snapshot)
        #expect(store.openDaily(monday) == .resume)

        // Replaying an already solved day still takes the daily slot: ask.
        _ = store.recordWin(size: .small, difficulty: .easy, time: 100, daily: tuesday)
        #expect(store.openDaily(tuesday) == .replacing(monday))

        // Once Monday is solved its save no longer counts.
        _ = store.recordWin(size: .small, difficulty: .easy, time: 100, daily: monday)
        #expect(store.openDaily(tuesday) == .fresh)
    }
}
