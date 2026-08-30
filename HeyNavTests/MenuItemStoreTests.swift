import Foundation
import Testing
@testable import HeyNav

struct MenuItemStoreTests {
    /// A throwaway suite per test. These run inside the app's test host, so touching
    /// `UserDefaults.standard` would read and overwrite the real app's pinned items.
    private func makeDefaults() -> UserDefaults {
        let suite = "HeyNavTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Weather has no default location, so it must not be pinnable until one is set.
    @Test func anItemNeedingSetupCannotBePinned() {
        let store = MenuItemStore(defaults: makeDefaults(), isSetUp: { $0 != .weather })
        let weather = store.items.first { $0.id == .weather }!

        #expect(store.needsSetup(weather))
        #expect(store.canPin(weather) == false)
        store.togglePin(.weather)
        #expect(store.items.first { $0.id == .weather }?.isPinned == false)

        // Other items are unaffected.
        store.togglePin(.battery)
        #expect(store.items.first { $0.id == .battery }?.isPinned == true)
    }

    @Test func becomingSetUpMakesAnItemPinnable() {
        var configured = false
        let store = MenuItemStore(defaults: makeDefaults(), isSetUp: { $0 != .weather || configured })
        store.togglePin(.weather)
        #expect(store.items.first { $0.id == .weather }?.isPinned == false)

        configured = true
        store.togglePin(.weather)
        #expect(store.items.first { $0.id == .weather }?.isPinned == true)
    }

    /// A location can be cleared between launches, so a saved pin isn't proof the item
    /// is still usable.
    @Test func aSavedPinForAnUnsetItemIsDroppedOnLoad() {
        let defaults = makeDefaults()
        defaults.set(["weather", "battery"], forKey: "pinnedItems")

        let store = MenuItemStore(defaults: defaults, isSetUp: { $0 != .weather })
        #expect(store.items.first { $0.id == .weather }?.isPinned == false)
        #expect(store.items.first { $0.id == .battery }?.isPinned == true)
    }

    @Test func nothingIsPinnedOnFirstRun() {
        let store = MenuItemStore(defaults: makeDefaults())
        #expect(store.items.allSatisfy { !$0.isPinned })
    }

    /// The behaviour that was previously impossible: the old canPin guard refused any
    /// icon while a widget was pinned, contradicting the popover's two sections.
    @Test func aWidgetAndThreeIconsCanBePinnedTogether() {
        let store = MenuItemStore(defaults: makeDefaults())
        store.togglePin(.nepaliDate)
        store.togglePin(.battery)
        store.togglePin(.weather)

        #expect(store.pinnedCount(for: .widget) == 1)
        #expect(store.pinnedCount(for: .icon) == 2)
    }

    @Test func sizeLimitsAreEnforcedIndependently() {
        let store = MenuItemStore(defaults: makeDefaults())
        store.togglePin(.nepaliDate)
        store.togglePin(.meeting)   // second widget - refused
        #expect(store.pinnedCount(for: .widget) == MenuItemStore.widgetPinLimit)
        #expect(store.items.first { $0.id == .meeting }?.isPinned == false)
    }

    @Test func unpinningFreesTheSlot() {
        let store = MenuItemStore(defaults: makeDefaults())
        store.togglePin(.nepaliDate)
        store.togglePin(.meeting)
        store.togglePin(.nepaliDate)   // unpin
        store.togglePin(.meeting)      // now fits
        #expect(store.items.first { $0.id == .meeting }?.isPinned == true)
    }

    @Test func pinsSurviveAReload() {
        let defaults = makeDefaults()
        let store = MenuItemStore(defaults: defaults)
        store.togglePin(.nepaliDate)
        store.togglePin(.battery)

        let reloaded = MenuItemStore(defaults: defaults)
        let pinned = Set(reloaded.items.filter(\.isPinned).map(\.id))
        #expect(pinned == [.nepaliDate, .battery])
    }

    @Test func aStaleOverLimitBlobIsClampedOnLoad() {
        let defaults = makeDefaults()
        // More icons than the limit allows, as an older build or a hand edit could leave.
        defaults.set(["battery", "weather", "nepaliDate", "meeting"], forKey: "pinnedItems")

        let store = MenuItemStore(defaults: defaults)
        #expect(store.pinnedCount(for: .icon) <= MenuItemStore.iconPinLimit)
        #expect(store.pinnedCount(for: .widget) <= MenuItemStore.widgetPinLimit)
    }

    @Test func unknownIdentifiersAreIgnored() {
        let defaults = makeDefaults()
        defaults.set(["network", "battery"], forKey: "pinnedItems")   // .network was removed
        let store = MenuItemStore(defaults: defaults)
        #expect(store.items.filter(\.isPinned).map(\.id) == [.battery])
    }
}
