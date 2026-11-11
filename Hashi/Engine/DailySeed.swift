import Foundation
#if canImport(PuzzleKit)
// Absent under a bare `swiftc` bench, which compiles PuzzleKit's sources into
// the same module instead (docs/ENGINEERING.md).
import PuzzleKit
#endif

/// Deterministic daily puzzle: every player gets the same board.
/// `DayKey` itself lives in PuzzleKit since 1.2; the seed prefix and the
/// weekly schedule are Hashi's.
/// **Never change the seed string or the schedule once shipped** — doing so
/// changes every future (and past) daily for everyone.
nonisolated enum DailySeed {
    /// FNV-1a over "hashi.daily.v1.YYYY-MM-DD".
    static func seed(for day: DayKey) -> UInt64 {
        DaySeed.seed(prefix: "hashi.daily.v1.", day: day)
    }

    /// Fixed weekly rhythm, gentle start of week, big weekend boards.
    static func spec(for day: DayKey) -> (size: BoardSize, difficulty: Difficulty) {
        switch weekday(of: day) {
        case 2, 3: (.small, .easy)        // Mon Tue
        case 4, 5: (.medium, .medium)     // Wed Thu
        case 6: (.medium, .hard)          // Fri
        case 7: (.large, .medium)         // Sat
        default: (.large, .hard)          // Sun
        }
    }

    /// 1 = Sunday … 7 = Saturday, from the date itself (never a `Calendar`).
    /// PuzzleKit's Julian-day weekday; its tests pin it equal to the Zeller
    /// formula 1.1 shipped with, on every day from 1900 to 2300.
    static func weekday(of day: DayKey) -> Int {
        day.weekday
    }
}
