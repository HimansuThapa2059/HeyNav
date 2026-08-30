import Foundation
import Observation

enum DateStyle: String, CaseIterable, Identifiable {
    case englishNumeric
    case englishNamed
    case englishNamedDayFirst
    case englishNamedShort
    case nepaliNumeric
    case nepaliNamed
    case nepaliNamedDayFirst
    case nepaliNamedShort

    var id: String { rawValue }

    var label: String {
        switch self {
        case .englishNumeric: return "2083-05-09"
        case .englishNamed: return "2083 Bhadra 9"
        case .englishNamedDayFirst: return "9 Bhadra 2083"
        case .englishNamedShort: return "Bhadra 9"
        case .nepaliNumeric: return "२०८३-०५-०९"
        case .nepaliNamed: return "२०८३ भदौ ९"
        case .nepaliNamedDayFirst: return "९ भदौ २०८३"
        case .nepaliNamedShort: return "भदौ ९"
        }
    }
}

@Observable
final class DateDisplaySettings {
    private static let storageKey = "dateStyle"

    @ObservationIgnored private let defaults: UserDefaults

    var dateStyle: DateStyle {
        didSet { defaults.set(dateStyle.rawValue, forKey: Self.storageKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.storageKey)
        self.dateStyle = DateStyle(rawValue: saved ?? "") ?? .nepaliNamed
    }
}
