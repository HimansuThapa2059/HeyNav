import SwiftUI

struct ContentView: View {
    let store: MenuItemStore
    let dateSettings: DateDisplaySettings
    let dayObserver: DayObserver
    let batteryMonitor: BatteryMonitor
    let weatherMonitor: WeatherMonitor
    let airQualityMonitor: AirQualityMonitor
    let weatherSettings: WeatherSettings
    let meetingMonitor: MeetingMonitor
    let onOpenSettings: () -> Void

    var widgetItems: [MenuItem] {
        store.items.filter { $0.size == .widget }
    }

    var iconItems: [MenuItem] {
        store.items.filter { $0.size == .icon }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                title: "Widget · pick \(MenuItemStore.widgetPinLimit)",
                count: "\(store.pinnedCount(for: .widget)) / \(MenuItemStore.widgetPinLimit)"
            )
            ForEach(widgetItems) { item in
                itemRow(item)
            }

            Divider().padding(.vertical, 6)

            sectionHeader(
                title: "Icons · pick up to \(MenuItemStore.iconPinLimit)",
                count: "\(store.pinnedCount(for: .icon)) / \(MenuItemStore.iconPinLimit)"
            )
            ForEach(iconItems) { item in
                itemRow(item)
            }

            Divider().padding(.vertical, 6)

            Button {
                onOpenSettings()
            } label: {
                bottomLabel(icon: "gearshape", title: "Open Settings")
            }
            .buttonStyle(.plain)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                bottomLabel(icon: "power", title: "Quit")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 280)
    }

    private func sectionHeader(title: String, count: String?) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let count {
                Text(count)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func itemRow(_ item: MenuItem) -> some View {
        let needsSetup = store.needsSetup(item)
        let disabled = !item.isPinned && !store.canPin(item)

        return HStack(spacing: 8) {
            Image(systemName: iconName(for: item.id))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if needsSetup {
                        Text("(setup needed)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(previewValue(for: item.id))
                    .font(.system(size: 13, weight: .medium))
            }

            Spacer()

            Button {
                store.togglePin(item.id)
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .help(needsSetup ? "Choose a location in Settings first" : "")
        }
        .opacity(disabled ? 0.4 : 1.0)
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if needsSetup {
                onOpenSettings()
            } else if item.id == .meeting, meetingMonitor.access == .denied {
                meetingMonitor.openCalendarPrivacySettings()
            }
        }
    }

    private func bottomLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func iconName(for id: MenuItemID) -> String {
        switch id {
        case .nepaliDate: return "calendar"
        case .meeting: return "calendar.badge.clock"
        case .battery: return batteryMonitor.symbolName
        case .weather: return "sun.max"
        case .airQuality: return airQualityMonitor.symbolName
        }
    }

    private func previewValue(for id: MenuItemID) -> String {
        switch id {
        case .nepaliDate:
            return NepaliDate.from(adDate: dayObserver.today)?.formatted(style: dateSettings.dateStyle) ?? "—"
        case .meeting:
            return meetingMonitor.popoverText
        case .battery:
            return batteryMonitor.displayText
        case .airQuality:
            guard weatherSettings.isConfigured else {
                return "Choose a location in Settings"
            }
            return airQualityMonitor.popoverText
        case .weather:
            guard weatherSettings.isConfigured else {
                return "Choose a location in Settings"
            }
            if let temp = weatherMonitor.temperature {
                return "\(temp)°"
            }
            return "Loading…"
        }
    }
}

#Preview {
    ContentView(
        store: MenuItemStore(),
        dateSettings: DateDisplaySettings(),
        dayObserver: DayObserver(),
        batteryMonitor: BatteryMonitor(),
        weatherMonitor: WeatherMonitor(settings: WeatherSettings()),
        airQualityMonitor: AirQualityMonitor(settings: WeatherSettings()),
        weatherSettings: WeatherSettings(),
        meetingMonitor: MeetingMonitor(settings: MeetingSettings()),
        onOpenSettings: {}
    )
}
