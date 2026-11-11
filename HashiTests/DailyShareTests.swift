import Foundation
import SwiftUI
import Testing
@testable import Hashi

@Suite("Daily share")
struct DailyShareTests {
    private let day = DayKey(year: 2026, month: 10, day: 20)

    private let english = Locale(identifier: "en_US")

    /// PuzzleKit's family format since 1.2.
    @Test func textCarriesDateSizeTimeAndStreak() {
        let text = DailyShareCard.text(day: day, rows: 10, cols: 10, time: 272, streak: 5,
                                       locale: english)
        #expect(text == "Just Hashi · Daily · Oct 20, 2026\nSolved in 4:32 · 10×10\n5-day streak\nhttps://kaikunze.de/justhashi/")
    }

    /// A one-day "streak" says nothing, and a late older daily has none.
    @Test func streakIsLeftOutWhenItSaysNothing() {
        for streak in [nil, 0, 1] as [Int?] {
            let text = DailyShareCard.text(day: day, rows: 7, cols: 7, time: 59, streak: streak,
                                           locale: english)
            #expect(!text.contains("streak"))
            #expect(text.contains("Solved in 0:59 · 7×7"))
        }
    }

    /// The date is spelled the same whatever the device's locale or calendar.
    @Test func dateLabelIsFixedEnglish() {
        #expect(DailyShareCard.dateLabel(DayKey(year: 2027, month: 1, day: 3)) == "3 Jan 2027")
        #expect(DailyShareCard.dateLabel(DayKey(year: 2026, month: 12, day: 31)) == "31 Dec 2026")
    }

    /// `ImageRenderer` returns nil rather than throwing when a view can't be
    /// drawn off screen; the win card would then quietly fall back to text.
    @Test @MainActor func cardRendersOffScreen() {
        let card = DailyShareCard(puzzle: Fixtures.crossing, day: day, time: 100, streak: 3)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        #expect(renderer.uiImage != nil)
    }
}
