import Foundation
import IOKit.ps
import Observation

@Observable
final class BatteryMonitor {
    var level: Int = 0
    var isCharging: Bool = false
    var isPluggedIn: Bool = false

    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    init() {
        update()

        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update() }
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    isolated deinit {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
    }

    func update() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else {
            return
        }

        if let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int {
            level = currentCapacity
        }

        if let charging = description[kIOPSIsChargingKey] as? Bool {
            isCharging = charging
        }

        if let state = description[kIOPSPowerSourceStateKey] as? String {
            isPluggedIn = state == kIOPSACPowerValue
        }
    }

    static func symbolName(forLevel level: Int) -> String {
        switch level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    static func displayText(level: Int, isCharging: Bool) -> String {
        isCharging ? "\(level)%⚡︎" : "\(level)%"
    }

    var symbolName: String { Self.symbolName(forLevel: level) }

    var displayText: String { Self.displayText(level: level, isCharging: isCharging) }
}
