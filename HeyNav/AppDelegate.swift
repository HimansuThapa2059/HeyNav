import Cocoa
import SwiftUI
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let minimumStatusItemLength: CGFloat = 24

    let dateSettings = DateDisplaySettings()
    let dayObserver = DayObserver()
    let batteryMonitor = BatteryMonitor()
    let weatherSettings = WeatherSettings()
    lazy var store = MenuItemStore(isSetUp: { [unowned self] id in
        switch id {
        case .weather, .airQuality: return self.weatherSettings.isConfigured
        default: return true
        }
    })
    let launchAtLogin = LaunchAtLogin()
    lazy var weatherMonitor = WeatherMonitor(settings: weatherSettings)
    lazy var airQualityMonitor = AirQualityMonitor(settings: weatherSettings)
    let meetingSettings = MeetingSettings()
    lazy var meetingMonitor = MeetingMonitor(settings: meetingSettings)

    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hostingView: NSHostingView<StatusBarLabelView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let labelView = StatusBarLabelView(
            store: store,
            dateSettings: dateSettings,
            dayObserver: dayObserver,
            batteryMonitor: batteryMonitor,
            weatherMonitor: weatherMonitor,
            airQualityMonitor: airQualityMonitor,
            meetingMonitor: meetingMonitor
        )
        hostingView = NSHostingView(rootView: labelView)

        if let button = statusItem.button {
            hostingView.translatesAutoresizingMaskIntoConstraints = true
            hostingView.autoresizingMask = [.width, .height]
            hostingView.frame = button.bounds
            button.addSubview(hostingView)

            button.target = self
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView(
                store: store,
                dateSettings: dateSettings,
                dayObserver: dayObserver,
                batteryMonitor: batteryMonitor,
                weatherMonitor: weatherMonitor,
                airQualityMonitor: airQualityMonitor,
                weatherSettings: weatherSettings,
                meetingMonitor: meetingMonitor,
                onOpenSettings: { [weak self] in self?.showSettings() }
            )
        )

        scheduleResize()
        observeLabelContents()

        Task { await meetingMonitor.requestAccess() }
    }

    private func observeLabelContents() {
        withObservationTracking {
            _ = store.items
            _ = dateSettings.dateStyle
            _ = dayObserver.today
            _ = batteryMonitor.level
            _ = batteryMonitor.isCharging
            _ = weatherMonitor.temperature
            _ = airQualityMonitor.index
            _ = meetingMonitor.nextEvent
            _ = meetingMonitor.access
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduleResize()
                self.observeLabelContents()
            }
        }
    }

    private func scheduleResize() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusItemSize()
        }
    }

    private func updateStatusItemSize() {
        hostingView.layoutSubtreeIfNeeded()

        let newLength = max(hostingView.fittingSize.width + 4, Self.minimumStatusItemLength)
        guard abs(statusItem.length - newLength) > 0.5 else { return }

        statusItem.length = newLength

        guard popover.isShown else { return }

        // Resizing moves the status item, so the open popover has to be re-anchored.
        // Closing first is what makes `show` take effect - it is a no-op on an already
        // open popover. `close()` not `performClose(_:)`, which runs the transient
        // dismissal path and tears down the whole list.
        //
        // Known costs: the popover blinks, and losing the transient event monitor means
        // clicking outside won't dismiss it until it is reopened.
        //
        // Deferred a hop because `statusItem.length` doesn't update `button.bounds`
        // until AppKit lays the item out again.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.popover.isShown, let button = self.statusItem.button else { return }
            self.popover.close()
            self.syncPopoverContentSize()
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func showSettings() {
        popover.performClose(nil)

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = FirstMouseHostingView(
                rootView: SettingsView(
                    settings: dateSettings,
                    weatherSettings: weatherSettings,
                    meetingSettings: meetingSettings,
                    dayObserver: dayObserver,
                    launchAtLogin: launchAtLogin
                )
            )
            window.title = "HeyNav Settings"
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
        NSApp.activate()
    }

    private func syncPopoverContentSize() {
        guard let view = popover.contentViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        let fitting = view.fittingSize
        guard fitting.width > 0, fitting.height > 0 else { return }
        popover.contentSize = fitting
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            syncPopoverContentSize()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
        }
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
