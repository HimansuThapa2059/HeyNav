import Foundation
import Observation

enum ItemSize {
    case icon
    case widget
}

enum MenuItemID: String, CaseIterable {
    case nepaliDate
    case battery
    case weather
    case airQuality
    case meeting
}

struct MenuItem: Identifiable {
    let id: MenuItemID
    let title: String
    let size: ItemSize
    var isPinned: Bool
}

@Observable
final class MenuItemStore {
    static let iconPinLimit = 3
    static let widgetPinLimit = 1

    private static let storageKey = "pinnedItems"

    @ObservationIgnored private let defaults: UserDefaults

    @ObservationIgnored private let isSetUp: (MenuItemID) -> Bool

    var items: [MenuItem] {
        didSet { persist() }
    }

    init(
        defaults: UserDefaults = .standard,
        isSetUp: @escaping (MenuItemID) -> Bool = { _ in true }
    ) {
        self.defaults = defaults
        self.isSetUp = isSetUp
        var catalogue: [MenuItem] = [
            MenuItem(id: .nepaliDate, title: "Today's date", size: .widget, isPinned: false),
            MenuItem(id: .meeting, title: "Upcoming meeting", size: .widget, isPinned: false),
            MenuItem(id: .battery, title: "Battery", size: .icon, isPinned: false),
            MenuItem(id: .weather, title: "Weather", size: .icon, isPinned: false),
            MenuItem(id: .airQuality, title: "Air quality", size: .icon, isPinned: false)
        ]

        let saved = defaults.stringArray(forKey: Self.storageKey) ?? []
        let savedIDs = Set(saved.compactMap(MenuItemID.init(rawValue:)))

        var restored: [ItemSize: Int] = [:]
        for index in catalogue.indices where savedIDs.contains(catalogue[index].id) {
            guard isSetUp(catalogue[index].id) else { continue }
            let size = catalogue[index].size
            let limit = size == .icon ? Self.iconPinLimit : Self.widgetPinLimit
            guard restored[size, default: 0] < limit else { continue }
            catalogue[index].isPinned = true
            restored[size, default: 0] += 1
        }

        self.items = catalogue
    }

    private func persist() {
        defaults.set(items.filter(\.isPinned).map(\.id.rawValue), forKey: Self.storageKey)
    }

    func pinnedCount(for size: ItemSize) -> Int {
        items.filter { $0.size == size && $0.isPinned }.count
    }

    func limit(for size: ItemSize) -> Int {
        size == .icon ? Self.iconPinLimit : Self.widgetPinLimit
    }

    func canPin(_ item: MenuItem) -> Bool {
        guard isSetUp(item.id) else { return false }
        return pinnedCount(for: item.size) < limit(for: item.size)
    }

    func needsSetup(_ item: MenuItem) -> Bool {
        !isSetUp(item.id)
    }

    func togglePin(_ id: MenuItemID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if items[index].isPinned {
            items[index].isPinned = false
        } else if canPin(items[index]) {
            items[index].isPinned = true
        }
    }
}
