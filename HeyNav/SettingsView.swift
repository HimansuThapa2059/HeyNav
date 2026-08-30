import SwiftUI

struct SettingsView: View {
    @Bindable var settings: DateDisplaySettings
    @Bindable var weatherSettings: WeatherSettings
    @Bindable var meetingSettings: MeetingSettings
    let dayObserver: DayObserver
    let launchAtLogin: LaunchAtLogin

    private enum Tab: String, CaseIterable, Identifiable {
        case general, date, calendar, location
        var id: String { rawValue }
        var label: String {
            switch self {
            case .general: return "General"
            case .date: return "Date"
            case .calendar: return "Calendar"
            case .location: return "Location"
            }
        }
    }

    @State private var tab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.label).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            Group {
                switch tab {
                case .general:
                    GeneralSettingsView(weatherSettings: weatherSettings, launchAtLogin: launchAtLogin)
                case .date:
                    DisplaySettingsView(settings: settings, dayObserver: dayObserver)
                case .calendar:
                    CalendarSettingsView(meetingSettings: meetingSettings)
                case .location:
                    LocationSettingsView(weatherSettings: weatherSettings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 460, height: 420)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var weatherSettings: WeatherSettings
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        Form {
            Section {
                Toggle("Launch HeyNav at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Temperature") {
                Picker("Unit", selection: $weatherSettings.unit) {
                    ForEach(WeatherSettings.Unit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
    }
}

private struct DisplaySettingsView: View {
    @Bindable var settings: DateDisplaySettings
    let dayObserver: DayObserver

    private var today: NepaliDate? {
        NepaliDate.from(adDate: dayObserver.today)
    }

    var body: some View {
        Form {
            Section("Date style") {
                Picker("", selection: $settings.dateStyle) {
                    ForEach(DateStyle.allCases) { style in
                        Text(preview(for: style)).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func preview(for style: DateStyle) -> String {
        today?.formatted(style: style) ?? style.label
    }
}

private struct CalendarSettingsView: View {
    @Bindable var meetingSettings: MeetingSettings

    var body: some View {
        Form {
            Section("Show the next event from") {
                Picker("", selection: $meetingSettings.window) {
                    ForEach(MeetingSettings.Window.allCases) { window in
                        Text(window.label).tag(window)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                if meetingSettings.window == .customDays {
                    Stepper(
                        value: $meetingSettings.customDays,
                        in: MeetingSettings.customDaysRange
                    ) {
                        Text("\(meetingSettings.customDays) day\(meetingSettings.customDays == 1 ? "" : "s") ahead")
                    }
                }
            }

            Section {
                Text(meetingSettings.emptyDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("When nothing is scheduled, the item reads")
            }
        }
        .formStyle(.grouped)
    }
}

private struct LocationSettingsView: View {
    @Bindable var weatherSettings: WeatherSettings

    @State private var query = ""
    @State private var results: [Geocoder.Place] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @FocusState private var searchFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                currentLocation
                searchSection
            }
            .padding(20)
        }
        .onAppear { searchFocused = true }
        .task(id: query) {
            guard trimmedQuery.count >= 2 else {
                results = []
                searchError = nil
                isSearching = false
                return
            }
            isSearching = true
            do {
                try await Task.sleep(for: .milliseconds(300))
                results = try await Geocoder.search(trimmedQuery)
                searchError = nil
                isSearching = false
            } catch is CancellationError {
            } catch let error as URLError where error.code == .cancelled {
            } catch {
                results = []
                searchError = error.localizedDescription
                isSearching = false
            }
        }
    }

    private var currentLocation: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WEATHER LOCATION")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: weatherSettings.isConfigured ? "mappin.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(weatherSettings.isConfigured ? Color.accentColor : .orange)

                if let place = weatherSettings.place {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(place.name).font(.system(size: 14, weight: .medium))
                        Text(String(format: "%.3f, %.3f", place.latitude, place.longitude))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clear") { weatherSettings.place = nil }
                        .controlSize(.small)
                } else {
                    Text("Not set up yet — search for a city below to enable the Weather item.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }


    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEARCH ANY CITY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Type a city name", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($searchFocused)
                if isSearching {
                    ProgressView().controlSize(.small)
                } else if !query.isEmpty {
                    Button {
                        clearSearch()
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(searchFocused ? Color.accentColor : .clear, lineWidth: 2)
            )
            .animation(.easeOut(duration: 0.15), value: searchFocused)

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(searchError == nil ? .secondary : Color.red)
            }

            if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { place in
                        LocationRow(place: place, isCurrent: isCurrent(place)) {
                            weatherSettings.place = .init(
                                name: place.name,
                                latitude: place.latitude,
                                longitude: place.longitude
                            )
                            clearSearch()
                        }
                        if place.id != results.last?.id { Divider() }
                    }
                }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var status: String? {
        if let searchError { return searchError }
        if isSearching { return "Searching…" }
        if trimmedQuery.count >= 2 && results.isEmpty { return "No matches for “\(trimmedQuery)”." }
        return nil
    }

    private func clearSearch() {
        query = ""
        results = []
        searchError = nil
    }

    private func isCurrent(_ place: Geocoder.Place) -> Bool {
        matches(place.latitude, place.longitude)
    }

    private func matches(_ latitude: Double, _ longitude: Double) -> Bool {
        guard let current = weatherSettings.place else { return false }
        return abs(latitude - current.latitude) < 0.0001 && abs(longitude - current.longitude) < 0.0001
    }
}

private struct LocationRow: View {
    let place: Geocoder.Place
    let isCurrent: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(place.name).font(.system(size: 13))
                Text(place.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(isHovering ? Color.accentColor.opacity(0.15) : .clear)
        .onHover { isHovering = $0 }
        .overlay(AcceptsFirstMouse())
        .onTapGesture(perform: onSelect)
    }
}

private struct AcceptsFirstMouse: NSViewRepresentable {
    final class AcceptingView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    func makeNSView(context: Context) -> AcceptingView { AcceptingView() }
    func updateNSView(_ nsView: AcceptingView, context: Context) {}
}
