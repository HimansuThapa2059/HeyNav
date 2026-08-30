import SwiftUI

struct StatusBarLabelView: View {
    let store: MenuItemStore
    let dateSettings: DateDisplaySettings
    let dayObserver: DayObserver
    let batteryMonitor: BatteryMonitor
    let weatherMonitor: WeatherMonitor
    let airQualityMonitor: AirQualityMonitor
    let meetingMonitor: MeetingMonitor

    var pinnedItems: [MenuItem] {
        store.items.filter { $0.isPinned }
    }

    var body: some View {
        HStack(spacing: 6) {
            if pinnedItems.isEmpty {
                Image(systemName: "square.3.layers.3d")
            } else {
                ForEach(Array(pinnedItems.enumerated()), id: \.element.id) { index, item in
                    itemView(for: item)
                    if index < pinnedItems.count - 1 {
                        Text("|")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 1)
                    }
                }
            }
        }
        .foregroundStyle(Color(nsColor: .labelColor))
        .padding(.horizontal, 6)
        .fixedSize()
    }

    @ViewBuilder
    private func itemView(for item: MenuItem) -> some View {
        switch item.id {
        case .nepaliDate:
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(NepaliDate.from(adDate: dayObserver.today)?.formatted(style: dateSettings.dateStyle) ?? "—")
            }
        case .weather:
            HStack(spacing: 4) {
                Image(systemName: "sun.max")
                Text(weatherMonitor.temperature.map { "\($0)°" } ?? "—")
            }
        case .airQuality:
            HStack(spacing: 4) {
                Image(systemName: airQualityMonitor.symbolName)
                Text(airQualityMonitor.statusBarText)
            }
        case .meeting:
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                Text(meetingMonitor.statusBarText)
            }
        case .battery:
            HStack(spacing: 4) {
                Image(systemName: batteryMonitor.symbolName)
                Text(batteryMonitor.displayText)
            }
        }
    }
}
