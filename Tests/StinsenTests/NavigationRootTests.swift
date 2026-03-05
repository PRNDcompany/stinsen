import XCTest
import SwiftUI
@testable import Stinsen

@MainActor
final class NavigationRootTests: XCTestCase {

    private func makeDummyItem(keyPath: Int = 0) -> NavigationRootItem {
        NavigationRootItem(keyPath: keyPath, input: nil, child: AnyView(EmptyView()))
    }

    // MARK: - updateItem with animation (pending state)

    func testUpdateItemWithAnimationSetsPendingSlot() {
        let root = NavigationRoot(item: makeDummyItem())
        XCTAssertNil(root.pendingSlot)

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        XCTAssertNotNil(root.pendingSlot)
    }

    func testUpdateItemWithAnimationSetsTransition() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        // Can't compare AnyTransition directly; verify slot 1 (new slot) has transition set
        XCTAssertNotNil(root.slotTransitions[1])
    }

    func testZIndexIncrementsOnAnimatedTransition() {
        let root = NavigationRoot(item: makeDummyItem())
        let initialZIndex = root.zIndex

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        XCTAssertEqual(root.zIndex, initialZIndex + 1)
    }

    func testUpdateItemWithoutAnimationDoesNotSetPendingSlot() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: nil,
            transition: .identity,
            zOrder: .front
        )

        XCTAssertNil(root.pendingSlot)
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
            transition: .opacity,
            zOrder: .front
        )
        root.commitTransition()  // Simulate onChange firing

        XCTAssertEqual(root.activeSlot, 1)
    }

    func testSlotsPreserveContentDuringTransition() {
        let root = NavigationRoot(item: makeDummyItem(keyPath: 100))

        root.updateItem(
            makeDummyItem(keyPath: 200),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
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
            transition: .identity,
            zOrder: .front
        )

        // activeSlot should NOT toggle
        XCTAssertEqual(root.activeSlot, 0)
        // Current slot updated in-place
        XCTAssertEqual(root.slots[0]?.keyPath, 200)
    }

    func testAlternatingSlotTransitions() {
        let root = NavigationRoot(item: makeDummyItem(keyPath: 1))

        // A→B: slot 0→1
        root.updateItem(makeDummyItem(keyPath: 2), animation: .easeIn, transition: .opacity, zOrder: .front)
        root.commitTransition()
        XCTAssertEqual(root.activeSlot, 1)
        XCTAssertEqual(root.slots[1]?.keyPath, 2)

        // B→C: slot 1→0
        root.updateItem(makeDummyItem(keyPath: 3), animation: .easeIn, transition: .opacity, zOrder: .front)
        root.commitTransition()
        XCTAssertEqual(root.activeSlot, 0)
        XCTAssertEqual(root.slots[0]?.keyPath, 3)

        // C→D: slot 0→1
        root.updateItem(makeDummyItem(keyPath: 4), animation: .easeIn, transition: .opacity, zOrder: .front)
        root.commitTransition()
        XCTAssertEqual(root.activeSlot, 1)
        XCTAssertEqual(root.slots[1]?.keyPath, 4)
    }

    // MARK: - zOrder

    func testSlotZIndexFront() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        // .front: new slot (1) gets higher zIndex (comes to front)
        XCTAssertEqual(root.slotZIndex[0], 0)  // old slot: lower
        XCTAssertEqual(root.slotZIndex[1], 1)  // new slot: higher (front)
    }

    func testSlotZIndexBack() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .back
        )

        // .back: old slot (0) gets higher zIndex (stays on top)
        XCTAssertEqual(root.slotZIndex[1], 0)  // new slot: lower (behind)
        XCTAssertEqual(root.slotZIndex[0], 1)  // old slot: higher (stays in front)
    }

    func testMultipleAnimatedTransitionsAccumulateZIndex() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(makeDummyItem(keyPath: 1), animation: .easeIn, transition: .opacity, zOrder: .front)
        root.commitTransition()
        root.updateItem(makeDummyItem(keyPath: 2), animation: .easeIn, transition: .opacity, zOrder: .front)
        root.commitTransition()
        root.updateItem(makeDummyItem(keyPath: 3), animation: .easeIn, transition: .opacity, zOrder: .front)

        XCTAssertEqual(root.zIndex, 3) // +1, +1, +1 = 3
    }

    // MARK: - commitTransition

    func testCommitTransitionClearsPendingSlot() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )
        XCTAssertNotNil(root.pendingSlot)

        root.commitTransition()

        XCTAssertNil(root.pendingSlot)
    }
}
