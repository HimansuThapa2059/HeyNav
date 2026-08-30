import AppKit
import EventKit
import Foundation
import Observation

@Observable
final class MeetingMonitor {
    enum Access {
        case notDetermined
        case denied
        case granted
    }

    struct Meeting: Equatable {
        let title: String
        let startDate: Date
    }

    private(set) var access: Access
    private(set) var nextEvent: Meeting?

    private static let tickInterval: TimeInterval = 60

    @ObservationIgnored private let settings: MeetingSettings
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var changeObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var tickTimer: Timer?

    init(settings: MeetingSettings) {
        self.settings = settings
        access = Self.currentAccess()

        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }

        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer

        observeSettings()
        refresh()
    }

    private func observeSettings() {
        withObservationTracking {
            _ = settings.window
            _ = settings.customDays
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeSettings()
                self.refresh()
            }
        }
    }

    isolated deinit {
        tickTimer?.invalidate()
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return .granted
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }

    func requestAccess() async {
        guard access == .notDetermined else { return }
        do {
            let granted = try await store.requestFullAccessToEvents()
            access = granted ? .granted : .denied
        } catch {
            access = .denied
        }
        refresh()
    }

    func refresh() {
        access = Self.currentAccess()
        guard access == .granted else {
            nextEvent = nil
            return
        }

        let now = Date()
        let window = settings.interval(from: now)
        let predicate = store.predicateForEvents(
            withStart: window.start,
            end: window.end,
            calendars: nil
        )

        let upcoming = store.events(matching: predicate)
            .lazy
            .filter { !$0.isAllDay }
            .compactMap { event -> Meeting? in
                guard let start = event.startDate,
                      let end = event.endDate,
                      end > now,
                      let title = event.title, !title.isEmpty
                else { return nil }
                return Meeting(title: title, startDate: start)
            }
            .min { $0.startDate < $1.startDate }

        if upcoming != nextEvent {
            nextEvent = upcoming
        }
    }

    func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @ObservationIgnored private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    var statusBarText: String {
        guard access == .granted, let nextEvent else { return "—" }
        let title = nextEvent.title.count > 20
            ? nextEvent.title.prefix(19) + "…"
            : nextEvent.title[...]
        return "\(title) · \(Self.time(nextEvent.startDate))"
    }

    var popoverText: String {
        switch access {
        case .notDetermined:
            return "Waiting for Calendar access…"
        case .denied:
            return "Calendar access denied — click to fix"
        case .granted:
            guard let nextEvent else { return settings.emptyDescription }
            return "\(nextEvent.title) at \(Self.time(nextEvent.startDate))"
        }
    }
}
