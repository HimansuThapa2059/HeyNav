import Foundation
import Observation

@Observable
final class WeatherSettings {
    struct Place: Codable, Equatable {
        var name: String
        var latitude: Double
        var longitude: Double
    }

    enum Unit: String, CaseIterable, Identifiable {
        case celsius
        case fahrenheit

        var id: String { rawValue }
        var label: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }
        var apiValue: String { rawValue }
    }

    private static let placeKey = "weatherPlace"
    private static let unitKey = "temperatureUnit"

    @ObservationIgnored private let defaults: UserDefaults

    var place: Place? {
        didSet {
            guard let place, let data = try? JSONEncoder().encode(place) else {
                defaults.removeObject(forKey: Self.placeKey)
                return
            }
            defaults.set(data, forKey: Self.placeKey)
        }
    }

    var isConfigured: Bool { place != nil }

    var unit: Unit {
        didSet { defaults.set(unit.rawValue, forKey: Self.unitKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Self.placeKey) {
            self.place = try? JSONDecoder().decode(Place.self, from: data)
        } else {
            self.place = nil
        }

        self.unit = Unit(rawValue: defaults.string(forKey: Self.unitKey) ?? "") ?? .celsius
    }
}

enum Geocoder {
    struct Place: Decodable, Identifiable, Equatable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?

        var subtitle: String {
            [admin1, country].compactMap { $0 }.joined(separator: ", ")
        }
    }

    private struct Response: Decodable {
        let results: [Place]?
    }

    static func search(_ query: String) async throws -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: trimmed),
            URLQueryItem(name: "count", value: "10")
        ]
        guard let url = components?.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try decode(data)
    }

    static func decode(_ data: Data) throws -> [Place] {
        try JSONDecoder().decode(Response.self, from: data).results ?? []
    }
}
