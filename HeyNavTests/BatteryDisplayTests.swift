import Testing
@testable import HeyNav

struct BatteryDisplayTests {
    /// Regression: 0-25% and 25-50% both used to return `battery.25`, so a dying
    /// battery looked identical to a half-full one.
    @Test(arguments: [
        (0, "battery.0"), (12, "battery.0"),
        (13, "battery.25"), (37, "battery.25"),
        (38, "battery.50"), (62, "battery.50"),
        (63, "battery.75"), (87, "battery.75"),
        (88, "battery.100"), (100, "battery.100"),
    ])
    func glyphTracksLevel(level: Int, expected: String) {
        #expect(BatteryMonitor.symbolName(forLevel: level) == expected)
    }

    /// Regression: charging used to swap the glyph for `battery.100.bolt` regardless of
    /// level, so a laptop plugged in at 20% drew a *full* battery. SF Symbols only ships
    /// a `.bolt` variant of `battery.100`, so charging is carried in the text instead.
    @Test func chargingNeverInflatesTheGlyph() {
        #expect(BatteryMonitor.symbolName(forLevel: 20) == "battery.25")
        #expect(BatteryMonitor.displayText(level: 20, isCharging: true) == "20%⚡︎")
        #expect(BatteryMonitor.displayText(level: 20, isCharging: false) == "20%")
    }
}
