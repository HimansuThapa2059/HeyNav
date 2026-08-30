import Foundation
import Observation

@Observable
final class AirQualityMonitor {
    
    enum Band {
        case good
        case moderate
        case unhealthyForSensitive
        case unhealthy
        case veryUnhealthy
        case hazardous

        var label: String {
            switch self {
            case .good: return "Good"
            case .moderate: return "Moderate"
            case .unhealthyForSensitive: return "Unhealthy for sensitive groups"
            case .unhealthy: return "Unhealthy"
            case .veryUnhealthy: return "Very unhealthy"
            case .hazardous: return "Hazardous"
            }
        }

        var symbolName: String {
            switch self {
            case .good: return "aqi.low"
            case .moderate, .unhealthyForSensitive: return "aqi.medium"
            case .unhealthy, .veryUnhealthy, .hazardous: return "aqi.high"
            }
        }
    }

    var index: Int?

    private static let refreshInterval: Duration = .seconds(1800)

    @ObservationIgnored private let settings: WeatherSettings
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(settings: WeatherSettings) {
        self.settings = settings

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                await self.refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }

        observeSettings()
    }

    deinit {
        refreshTask?.cancel()
    }

    /// Re-fetch when the location changes
    private func observeSettings() {
        withObservationTracking {
            _ = settings.place
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeSettings()
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard settings.isConfigured else {
            index = nil
            return
        }
        guard let url = requestURL else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            index = try Self.decode(data)
        } catch {
            // Keep the last reading: a failed poll shouldn't blank the menu bar.
        }
    }

    private var requestURL: URL? {
        guard let place = settings.place else { return nil }
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "us_aqi")
        ]
        return components?.url
    }

    static func decode(_ data: Data) throws -> Int? {
        try JSONDecoder().decode(Response.self, from: data).current.usAQI.map { Int($0.rounded()) }
    }

    private struct Response: Decodable {
        struct Current: Decodable {
            let usAQI: Double?

            enum CodingKeys: String, CodingKey {
                case usAQI = "us_aqi"
            }
        }

        let current: Current
    }

    nonisolated static func band(for index: Int) -> Band {
        switch index {
        case ..<51: return .good
        case ..<101: return .moderate
        case ..<151: return .unhealthyForSensitive
        case ..<201: return .unhealthy
        case ..<301: return .veryUnhealthy
        default: return .hazardous
        }
    }

    var band: Band? { index.map(Self.band(for:)) }

    var symbolName: String { band?.symbolName ?? "aqi.medium" }

    var statusBarText: String { index.map(String.init) ?? "—" }

    var popoverText: String {
        guard let index, let band else { return "Loading…" }
        return "\(index) · \(band.label)"
    }
}
