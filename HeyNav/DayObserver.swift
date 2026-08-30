import AppKit
import Foundation
import Observation

@Observable
final class DayObserver {
    private(set) var today: Date = Calendar.current.startOfDay(for: Date())

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var wakeObserver: (any NSObjectProtocol)?

    init() {
        scheduleNextMidnight()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    isolated deinit {
        timer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    private func refresh() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        if startOfToday != today {
            today = startOfToday
        }
        scheduleNextMidnight()
    }

    private func scheduleNextMidnight() {
        timer?.invalidate()

        let calendar = Calendar.current
        guard let nextMidnight = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: Date())
        ) else {
            return
        }

        let timer = Timer(fire: nextMidnight, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
