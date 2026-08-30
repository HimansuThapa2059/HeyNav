import Foundation
import Observation

@Observable
final class WeatherMonitor {
    var temperature: Int?

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

    private func observeSettings() {
        withObservationTracking {
            _ = settings.place
            _ = settings.unit
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
            temperature = nil
            return
        }
        guard let url = forecastURL else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let forecast = try JSONDecoder().decode(Forecast.self, from: data)
            temperature = Int(forecast.current.temperature.rounded())
        } catch {
        }
    }

    private var forecastURL: URL? {
        guard let place = settings.place else { return nil }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m"),
            URLQueryItem(name: "temperature_unit", value: settings.unit.apiValue)
        ]
        return components?.url
    }

    private struct Forecast: Decodable {
        struct Current: Decodable {
            let temperature: Double

            enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m"
            }
        }

        let current: Current
    }
}
