import Foundation
import SwiftUI

struct NavigationRootItem {

    /// Which `@Root` this is.
    ///
    /// A `RouteKey`, not a `KeyPath.hashValue`. `hasRoot(_:)` answers by comparing this
    /// against the route it was asked about, and comparing hashes there is the same
    /// mistake the routed screens were already fixed for: a collision does not fail
    /// loudly, it answers `hasRoot(\.authenticated)` with the unauthenticated root's
    /// child and hands the caller a coordinator of the wrong type to cast.
    let route: RouteKey
    let input: Any?
    // Strong reference: root coordinator has no retain cycle
    // (parent reference is weak, so Coordinator → Stack → Root → child is safe)
    let child: ViewPresentable

    init(route: RouteKey, input: Any?, child: ViewPresentable) {
        self.route = route
        self.input = input
        self.child = child
    }
}

struct RootSlot {
    var item: NavigationRootItem
    var transition: AnyTransition = .identity
    var zIndex: Double = 0
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
@MainActor
public class NavigationRoot: ObservableObject {
    var activeSlotIndex: Int = 0

    var activeSlot: RootSlot? {
        slots[safe: activeSlotIndex]
    }

    var slots: [RootSlot]
    var zIndex: Double = 0

    init(item: NavigationRootItem, transition: AnyTransition = .identity) {
        let slot = RootSlot(item: item, transition: transition, zIndex: zIndex)
        self.slots = [slot]
    }

    func updateItem(
        _ newItem: NavigationRootItem,
        animation: Animation?,
        transition: AnyTransition,
        zOrder: RootLayer
    ) {
        if let animation {
            withAnimation(animation) {
                activeSlotIndex = prepareSlotIndex(for: newItem, transition: transition, zOrder: zOrder)
                objectWillChange.send()
            }
        } else {
            slots[activeSlotIndex] = RootSlot(item: newItem, transition: transition, zIndex: zIndex)
            objectWillChange.send()
        }
    }

    private func prepareSlotIndex(for item: NavigationRootItem, transition: AnyTransition, zOrder: RootLayer) -> Int {
        let slotIndex = 1 - activeSlotIndex
        zIndex += zOrder == .front ? 1 : -1
        setSlot(
            at: slotIndex,
            RootSlot(item: item, transition: transition, zIndex: zIndex)
        )
        return slotIndex
    }

    private func setSlot(at index: Int, _ slot: RootSlot) {
        if index < slots.count {
            slots[index] = slot
        } else {
            slots.append(slot)
        }
    }
}
