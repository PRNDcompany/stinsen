import XCTest
import SwiftUI
@testable import Stinsen

@MainActor
final class NavigationRootTests: XCTestCase {

    private func makeDummyItem(keyPath: Int = 0) -> NavigationRootItem {
        NavigationRootItem(keyPath: keyPath, input: nil, child: AnyView(EmptyView()))
    }

    // MARK: - updateItem with animation (pending state)

    func testUpdateItemWithAnimationSetsPendingTransitionId() {
        let root = NavigationRoot(item: makeDummyItem())
        XCTAssertNil(root.pendingTransitionId)

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity
        )

        XCTAssertNotNil(root.pendingTransitionId)
    }

    func testUpdateItemWithAnimationSetsTransition() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity
        )

        // Both slots use the same unified transition (can't compare AnyTransition directly,
        // but verify it doesn't crash and transition is set)
        XCTAssertNotNil(root.transition)
    }

    func testZIndexIncrementsOnAnimatedTransition() {
        let root = NavigationRoot(item: makeDummyItem())
        let initialZIndex = root.zIndex

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity
        )

        XCTAssertEqual(root.zIndex, initialZIndex + 1)
    }

    func testUpdateItemWithoutAnimationDoesNotSetPendingId() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: nil,
            transition: .identity
        )

        XCTAssertNil(root.pendingTransitionId)
    }

    // MARK: - Two-Slot behavior

    func testInitialActiveSlotIsZero() {
        let root = NavigationRoot(item: makeDummyItem())
        XCTAssertEqual(root.activeSlot, 0)
    }

    func testInitialSlotZeroHasItem() {
        let root = NavigationRoot(item: makeDummyItem(keyPath: 42))
        XCTAssertNotNil(root.slots[0])
        XCTAssertEqual(root.slots[0]?.keyPath, 42)
    }

    func testActiveSlotTogglesOnAnimatedTransition() {
        let root = NavigationRoot(item: makeDummyItem())
        XCTAssertEqual(root.activeSlot, 0)

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity
        )
        root.commitTransition()  // Simulate onChange firing

        XCTAssertEqual(root.activeSlot, 1)
    }

    func testSlotsPreserveContentDuringTransition() {
        let root = NavigationRoot(item: makeDummyItem(keyPath: 100))

        root.updateItem(
            makeDummyItem(keyPath: 200),
            animation: .easeInOut,
            transition: .opacity
        )

        // Old slot still has A, new slot has B (before commit)
        XCTAssertEqual(root.slots[0]?.keyPath, 100)
        XCTAssertEqual(root.slots[1]?.keyPath, 200)
    }

    func testNonAnimatedTransitionUpdatesSameSlot() {
        let root = NavigationRoot(item: makeDummyItem(keyPath: 100))
        XCTAssertEqual(root.activeSlot, 0)

        root.updateItem(
            makeDummyItem(keyPath: 200),
            animation: nil,
            transition: .identity
        )

        // activeSlot should NOT toggle
        XCTAssertEqual(root.activeSlot, 0)
        // Current slot updated in-place
        XCTAssertEqual(root.slots[0]?.keyPath, 200)
    }

    func testAlternatingSlotTransitions() {
        let root = NavigationRoot(item: makeDummyItem(keyPath: 1))

        // A→B: slot 0→1
        root.updateItem(makeDummyItem(keyPath: 2), animation: .easeIn, transition: .opacity)
        root.commitTransition()
        XCTAssertEqual(root.activeSlot, 1)
        XCTAssertEqual(root.slots[1]?.keyPath, 2)

        // B→C: slot 1→0
        root.updateItem(makeDummyItem(keyPath: 3), animation: .easeIn, transition: .opacity)
        root.commitTransition()
        XCTAssertEqual(root.activeSlot, 0)
        XCTAssertEqual(root.slots[0]?.keyPath, 3)

        // C→D: slot 0→1
        root.updateItem(makeDummyItem(keyPath: 4), animation: .easeIn, transition: .opacity)
        root.commitTransition()
        XCTAssertEqual(root.activeSlot, 1)
        XCTAssertEqual(root.slots[1]?.keyPath, 4)
    }

    func testSlotZIndexAssignment() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity
        )

        // New slot (1) gets lower zIndex; old slot (0) stays on top (higher zIndex)
        XCTAssertEqual(root.slotZIndex[1], 0)
        XCTAssertEqual(root.slotZIndex[0], 1)
    }

    func testMultipleAnimatedTransitionsAccumulateZIndex() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(makeDummyItem(keyPath: 1), animation: .easeIn, transition: .opacity)
        root.commitTransition()
        root.updateItem(makeDummyItem(keyPath: 2), animation: .easeIn, transition: .opacity)
        root.commitTransition()
        root.updateItem(makeDummyItem(keyPath: 3), animation: .easeIn, transition: .opacity)

        XCTAssertEqual(root.zIndex, 3) // +1, +1, +1 = 3
    }

    // MARK: - commitTransition

    func testCommitTransitionClearsPendingState() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity
        )
        XCTAssertNotNil(root.pendingTransitionId)
        XCTAssertNotNil(root.pendingItem)

        root.commitTransition()

        XCTAssertNil(root.pendingTransitionId)
        XCTAssertNil(root.pendingItem)
    }
}
