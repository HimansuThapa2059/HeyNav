import Foundation
import Testing
@testable import HeyNav

struct MeetingSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "HeyNavTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kathmandu")!
        return calendar
    }

    /// 2026-08-25 is a Tuesday, 14:30 local.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 14, minute: 30))!
    }

    @Test func defaultsToNext24Hours() {
        let settings = MeetingSettings(defaults: makeDefaults())
        #expect(settings.window == .next24Hours)
        #expect(settings.customDays == 7)
    }

    @Test func settingsSurviveAReload() {
        let defaults = makeDefaults()
        let settings = MeetingSettings(defaults: defaults)
        settings.window = .customDays
        settings.customDays = 21

        let reloaded = MeetingSettings(defaults: defaults)
        #expect(reloaded.window == .customDays)
        #expect(reloaded.customDays == 21)
    }

    @Test func customDaysIsClampedToItsRange() {
        let settings = MeetingSettings(defaults: makeDefaults())
        settings.customDays = 500
        #expect(settings.customDays == MeetingSettings.customDaysRange.upperBound)
        settings.customDays = -3
        #expect(settings.customDays == MeetingSettings.customDaysRange.lowerBound)
    }

    @Test func restOfTodayEndsAtTheNextMidnight() {
        let settings = MeetingSettings(defaults: makeDefaults())
        settings.window = .restOfToday
        let end = settings.interval(from: now, calendar: calendar).end
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: end)
        #expect(parts.day == 26)
        #expect(parts.hour == 0)
    }

    @Test func next24HoursEndsADayLater() {
        let settings = MeetingSettings(defaults: makeDefaults())
        settings.window = .next24Hours
        let interval = settings.interval(from: now, calendar: calendar)
        #expect(interval.duration == 24 * 60 * 60)
    }

    @Test func customDaysUsesTheChosenCount() {
        let settings = MeetingSettings(defaults: makeDefaults())
        settings.window = .customDays
        settings.customDays = 3
        let end = settings.interval(from: now, calendar: calendar).end
        #expect(calendar.dateComponents([.day], from: now, to: end).day == 3)
    }

    @Test func widerWindowsExtendFurtherOut() {
        let settings = MeetingSettings(defaults: makeDefaults())
        settings.window = .restOfToday
        let today = settings.interval(from: now, calendar: calendar).end
        settings.window = .thisWeek
        let week = settings.interval(from: now, calendar: calendar).end
        settings.window = .thisMonth
        let month = settings.interval(from: now, calendar: calendar).end

        #expect(today <= week)
        #expect(week <= month)
    }

    /// Every window must produce a non-empty interval, since DateInterval traps when
    /// its end precedes its start.
    @Test func noWindowEndsBeforeItStarts() {
        let settings = MeetingSettings(defaults: makeDefaults())
        for window in MeetingSettings.Window.allCases {
            settings.window = window
            let interval = settings.interval(from: now, calendar: calendar)
            #expect(interval.end >= interval.start, "\(window.label) produced a negative interval")
        }
    }

    @Test func emptyDescriptionNamesTheChosenWindow() {
        let settings = MeetingSettings(defaults: makeDefaults())
        settings.window = .customDays
        settings.customDays = 1
        #expect(settings.emptyDescription == "Nothing in the next 1 day")
        settings.customDays = 5
        #expect(settings.emptyDescription == "Nothing in the next 5 days")
    }
}
