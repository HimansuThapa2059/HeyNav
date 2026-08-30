import Foundation
import Testing
@testable import HeyNav

struct AirQualityTests {
    /// Boundaries of the US AQI scale, checked on both sides of each break.
    @Test(arguments: [
        (0, "Good"), (50, "Good"),
        (51, "Moderate"), (100, "Moderate"),
        (101, "Unhealthy for sensitive groups"), (150, "Unhealthy for sensitive groups"),
        (151, "Unhealthy"), (200, "Unhealthy"),
        (201, "Very unhealthy"), (300, "Very unhealthy"),
        (301, "Hazardous"), (500, "Hazardous"),
    ])
    func bandBoundaries(index: Int, expected: String) {
        #expect(AirQualityMonitor.band(for: index).label == expected)
    }

    /// SF Symbols ships only three AQI glyphs, so six bands collapse onto them.
    @Test func glyphsCollapseTheBands() {
        #expect(AirQualityMonitor.band(for: 20).symbolName == "aqi.low")
        #expect(AirQualityMonitor.band(for: 75).symbolName == "aqi.medium")
        #expect(AirQualityMonitor.band(for: 130).symbolName == "aqi.medium")
        #expect(AirQualityMonitor.band(for: 180).symbolName == "aqi.high")
        #expect(AirQualityMonitor.band(for: 400).symbolName == "aqi.high")
    }

    @Test func decodesARealResponse() throws {
        let json = """
        {"latitude":27.7,"longitude":83.4,"current_units":{"us_aqi":"USAQI"},
         "current":{"time":"2026-08-26T16:45","interval":3600,"us_aqi":68}}
        """
        #expect(try AirQualityMonitor.decode(Data(json.utf8)) == 68)
    }

    /// A station with no reading for the hour sends null rather than omitting the key,
    /// and that is a missing value, not a failure.
    @Test func nullReadingDecodesToNil() throws {
        let json = #"{"current":{"time":"2026-08-26T16:45","us_aqi":null}}"#
        #expect(try AirQualityMonitor.decode(Data(json.utf8)) == nil)
    }

    @Test func fractionalValuesRound() throws {
        #expect(try AirQualityMonitor.decode(Data(#"{"current":{"us_aqi":67.6}}"#.utf8)) == 68)
    }

    @Test func malformedJsonThrows() {
        #expect(throws: (any Error).self) {
            try AirQualityMonitor.decode(Data("nope".utf8))
        }
    }
}

extension MenuItemStoreTests {
    /// Air quality needs the same coordinates weather does, so it must be gated too.
    @Test func airQualityNeedsALocationBeforeItCanBePinned() {
        let suite = "HeyNavTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = MenuItemStore(defaults: defaults, isSetUp: { $0 != .weather && $0 != .airQuality })
        let aqi = store.items.first { $0.id == .airQuality }!
        #expect(store.needsSetup(aqi))
        store.togglePin(.airQuality)
        #expect(store.items.first { $0.id == .airQuality }?.isPinned == false)
    }
}
