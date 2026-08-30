import Foundation
import Testing
@testable import HeyNav

struct WeatherSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "HeyNavTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// There is deliberately no default location - guessing one would quietly show
    /// someone else's weather.
    @Test func startsUnconfigured() {
        let settings = WeatherSettings(defaults: makeDefaults())
        #expect(settings.place == nil)
        #expect(settings.isConfigured == false)
        #expect(settings.unit == .celsius)
    }

    @Test func clearingThePlaceRemovesItFromStorage() {
        let defaults = makeDefaults()
        let settings = WeatherSettings(defaults: defaults)
        settings.place = .init(name: "Butwal", latitude: 27.70055, longitude: 83.44836)
        #expect(WeatherSettings(defaults: defaults).isConfigured)

        settings.place = nil
        #expect(defaults.data(forKey: "weatherPlace") == nil)
        #expect(WeatherSettings(defaults: defaults).isConfigured == false)
    }

    @Test func placeAndUnitSurviveAReload() {
        let defaults = makeDefaults()
        let settings = WeatherSettings(defaults: defaults)
        settings.place = .init(name: "Pokhara", latitude: 28.2096, longitude: 83.9856)
        settings.unit = .fahrenheit

        let reloaded = WeatherSettings(defaults: defaults)
        #expect(reloaded.place?.name == "Pokhara")
        #expect(reloaded.place?.latitude == 28.2096)
        #expect(reloaded.unit == .fahrenheit)
    }

    @Test func aCorruptStoredPlaceReadsAsUnconfigured() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "weatherPlace")
        #expect(WeatherSettings(defaults: defaults).isConfigured == false)
    }

    @Test func unitMapsToTheApiParameter() {
        #expect(WeatherSettings.Unit.celsius.apiValue == "celsius")
        #expect(WeatherSettings.Unit.fahrenheit.apiValue == "fahrenheit")
    }
}

struct DateDisplaySettingsTests {
    @Test func dateStyleSurvivesAReload() {
        let suite = "HeyNavTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let settings = DateDisplaySettings(defaults: defaults)
        #expect(settings.dateStyle == .nepaliNamed)   // default
        settings.dateStyle = .englishNumeric

        #expect(DateDisplaySettings(defaults: defaults).dateStyle == .englishNumeric)
    }
}
