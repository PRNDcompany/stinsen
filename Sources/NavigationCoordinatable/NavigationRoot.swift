import Foundation
import SwiftUI

struct NavigationRootItem {
    let keyPath: Int
    let input: Any?
    // Strong reference: root coordinator has no retain cycle
    // (parent reference is weak, so Coordinator → Stack → Root → child is safe)
    let child: ViewPresentable

    init(keyPath: Int, input: Any?, child: ViewPresentable) {
        self.keyPath = keyPath
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
