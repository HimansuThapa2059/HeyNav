import Foundation
import Observation

@Observable
final class MeetingSettings {
    enum Window: String, CaseIterable, Identifiable {
        case restOfToday
        case next24Hours
        case thisWeek
        case thisMonth
        case customDays

        var id: String { rawValue }

        var label: String {
            switch self {
            case .restOfToday: return "Rest of today"
            case .next24Hours: return "Next 24 hours"
            case .thisWeek: return "This week"
            case .thisMonth: return "This month"
            case .customDays: return "Next N days"
            }
        }
    }

    static let customDaysRange = 1...90

    private static let windowKey = "meetingWindow"
    private static let customDaysKey = "meetingCustomDays"

    @ObservationIgnored private let defaults: UserDefaults

    var window: Window {
        didSet { defaults.set(window.rawValue, forKey: Self.windowKey) }
    }

    var customDays: Int {
        didSet {
            let clamped = min(max(customDays, Self.customDaysRange.lowerBound), Self.customDaysRange.upperBound)
            if clamped != customDays {
                customDays = clamped
                return
            }
            defaults.set(customDays, forKey: Self.customDaysKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.window = Window(rawValue: defaults.string(forKey: Self.windowKey) ?? "") ?? .next24Hours
        let saved = defaults.integer(forKey: Self.customDaysKey)   // 0 when unset
        self.customDays = Self.customDaysRange.contains(saved) ? saved : 7
    }

    func interval(from now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let fallback = now.addingTimeInterval(24 * 60 * 60)
        let end: Date

        switch window {
        case .restOfToday:
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? fallback
        case .next24Hours:
            end = calendar.date(byAdding: .hour, value: 24, to: now) ?? fallback
        case .thisWeek:
            end = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? fallback
        case .thisMonth:
            end = calendar.dateInterval(of: .month, for: now)?.end ?? fallback
        case .customDays:
            end = calendar.date(byAdding: .day, value: customDays, to: now) ?? fallback
        }

        return DateInterval(start: now, end: max(end, now))
    }

    var emptyDescription: String {
        switch window {
        case .restOfToday: return "Nothing else today"
        case .next24Hours: return "Nothing in the next 24 hours"
        case .thisWeek: return "Nothing else this week"
        case .thisMonth: return "Nothing else this month"
        case .customDays: return "Nothing in the next \(customDays) day\(customDays == 1 ? "" : "s")"
        }
    }
}
