import Foundation
import Testing
@testable import HeyNav

/// The conversion table is hand-maintained and its boundaries are silently load-bearing:
/// outside them `from(adDate:)` returns nil and the menu bar falls back to an em dash.
struct NepaliDateTests {
    private func ad(_ year: Int, _ month: Int, _ day: Int) -> Date {
        // Same calendar NepaliDate itself uses, so both agree on the local day.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func epochIsFirstDayOfBS2000() {
        let date = NepaliDate.from(adDate: ad(1943, 4, 14))
        #expect(date?.year == 2000)
        #expect(date?.month == 1)
        #expect(date?.day == 1)
    }

    @Test func newYearConversions() {
        #expect(NepaliDate.from(adDate: ad(2025, 4, 14)).map { [$0.year, $0.month, $0.day] } == [2082, 1, 1])
        #expect(NepaliDate.from(adDate: ad(2026, 4, 14)).map { [$0.year, $0.month, $0.day] } == [2083, 1, 1])
    }

    @Test func midYearConversion() {
        #expect(NepaliDate.from(adDate: ad(2026, 8, 25)).map { [$0.year, $0.month, $0.day] } == [2083, 5, 9])
    }

    /// The table ends at BS 2088, which is AD 2032-04-13. This is a documented limit,
    /// not a bug - the official calendar isn't published further out - so the contract
    /// is that it degrades to nil rather than returning a wrong date.
    @Test func lastCoveredDayConverts() {
        #expect(NepaliDate.from(adDate: ad(2032, 4, 13)).map { [$0.year, $0.month, $0.day] } == [2088, 12, 30])
    }

    @Test func outOfRangeDatesReturnNil() {
        #expect(NepaliDate.from(adDate: ad(2032, 4, 14)) == nil)
        #expect(NepaliDate.from(adDate: ad(1943, 4, 13)) == nil)
    }

    @Test func everyTableRowSumsToItsStatedTotal() {
        for row in NepaliDate.calendarData {
            #expect(row[1...12].reduce(0, +) == row[13], "BS \(row[0]) months do not sum to its total")
        }
    }

    /// Numeric styles pad for stable width; named styles don't, because nobody writes
    /// "Bhadra 09" by hand.
    @Test func formattingStyles() {
        let date = NepaliDate(year: 2083, month: 5, day: 9)
        #expect(date.formatted(style: .englishNumeric) == "2083-05-09")
        #expect(date.formatted(style: .englishNamed) == "2083 Bhadra 9")
        #expect(date.formatted(style: .englishNamedDayFirst) == "9 Bhadra 2083")
        #expect(date.formatted(style: .englishNamedShort) == "Bhadra 9")
        #expect(date.formatted(style: .nepaliNumeric) == "२०८३-०५-०९")
        #expect(date.formatted(style: .nepaliNamed) == "२०८३ भदौ ९")
        #expect(date.formatted(style: .nepaliNamedDayFirst) == "९ भदौ २०८३")
        #expect(date.formatted(style: .nepaliNamedShort) == "भदौ ९")
    }

    @Test func everyStyleRendersSomething() {
        let date = NepaliDate(year: 2083, month: 5, day: 9)
        for style in DateStyle.allCases {
            #expect(!date.formatted(style: style).isEmpty)
            #expect(date.formatted(style: style) != "—")
        }
    }

    @Test func formattingRejectsAnImpossibleMonth() {
        // Guards the unguarded month-name subscript that a bad table row could trip.
        #expect(NepaliDate(year: 2083, month: 13, day: 1).formatted(style: .englishNamed) == "—")
    }
}
