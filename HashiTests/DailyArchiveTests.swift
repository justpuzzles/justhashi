import Foundation
import Testing
@testable import Hashi

@Suite("Daily archive")
struct DailyArchiveTests {

    @Test func newestFirstAndTodayExcluded() {
        let today = DayKey(year: 2026, month: 10, day: 20)
        let days = DailyArchive.days(before: today)
        #expect(days.first == DayKey(year: 2026, month: 10, day: 19))
        #expect(!days.contains(today))
        #expect(zip(days, days.dropFirst()).allSatisfy { $1 < $0 })
    }

    @Test func stopsAtLaunchDay() {
        let days = DailyArchive.days(before: DayKey(year: 2026, month: 8, day: 11))
        #expect(days == [DayKey(year: 2026, month: 8, day: 10),
                         DayKey(year: 2026, month: 8, day: 9),
                         DailyArchive.firstDay])
        #expect(DailyArchive.days(before: DailyArchive.firstDay).isEmpty)
    }

    @Test func capsAtAYear() {
        let days = DailyArchive.days(before: DayKey(year: 2030, month: 1, day: 1))
        #expect(days.count == 366)
    }

    /// Opening a past board is paid; today's stays free.
    @Test func pastDailiesNeedTheUnlock() {
        #expect(!FeatureGate.isAvailable(.dailyArchive, unlocked: false))
        #expect(FeatureGate.isAvailable(.dailyArchive, unlocked: true))
        #expect(FeatureGate.isDailyAvailable(DayKey(year: 2026, month: 10, day: 20), unlocked: false))
    }
}

@Suite("Day key calendar")
struct DayKeyCalendarTests {
    /// The daily is keyed on Gregorian Y-M-D whatever calendar the phone uses;
    /// a Japanese-calendar year (Reiwa 8) would otherwise seed a different board.
    @Test func defaultCalendarIsGregorianLocalTime() {
        #expect(DayKey.localCalendar.identifier == .gregorian)
        #expect(DayKey.localCalendar.timeZone == TimeZone.current)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let parts = DayKey.localCalendar.dateComponents([.year, .month, .day], from: date)
        #expect(DayKey(date: date) == DayKey(year: parts.year!, month: parts.month!, day: parts.day!))
    }

    @Test func otherCalendarsGiveOtherYears() {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = .current
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(DayKey(date: date, calendar: japanese) != DayKey(date: date))
    }
}
