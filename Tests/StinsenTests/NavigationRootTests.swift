import XCTest
import SwiftUI
@testable import Stinsen

@MainActor
final class NavigationRootTests: XCTestCase {

    private func makeDummyItem(keyPath: Int = 0) -> NavigationRootItem {
        NavigationRootItem(keyPath: keyPath, input: nil, child: AnyView(EmptyView()))
    }

    // MARK: - updateItem with animation

    func testUpdateItemWithAnimationChangesRootId() {
        let root = NavigationRoot(item: makeDummyItem())
        let initialId = root.rootId

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            bringToFront: true
        )

        XCTAssertNotEqual(root.rootId, initialId)
    }

    func testUpdateItemWithAnimationSetsTransition() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .slide,
            bringToFront: true
        )

        // transition is stored (we can't compare AnyTransition directly,
        // but we verify it doesn't crash and the property is set)
        XCTAssertNotNil(root.transition)
    }

    func testZIndexIncrementsOnBringToFront() {
        let root = NavigationRoot(item: makeDummyItem())
        let initialZIndex = root.zIndex

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            bringToFront: true
        )

        XCTAssertEqual(root.zIndex, initialZIndex + 1)
    }

    func testZIndexDecrementsOnBringToBack() {
        let root = NavigationRoot(item: makeDummyItem())
        let initialZIndex = root.zIndex

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            bringToFront: false
        )

        XCTAssertEqual(root.zIndex, initialZIndex - 1)
    }

    func testUpdateItemWithoutAnimationDoesNotChangeRootId() {
        let root = NavigationRoot(item: makeDummyItem())
        let initialId = root.rootId

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: nil,
            transition: .identity,
            bringToFront: true
        )

        XCTAssertEqual(root.rootId, initialId)
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
            bringToFront: true
        )

        XCTAssertEqual(root.activeSlot, 1)
    }

    func testSlotsPreserveContentDuringTransition() {
        let root = NavigationRoot(item: makeDummyItem(keyPath: 100))

        root.updateItem(
            makeDummyItem(keyPath: 200),
            animation: .easeInOut,
            transition: .opacity,
            bringToFront: true
        )

        // Old slot still has A, new slot has B
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
            bringToFront: true
        )

        // activeSlot should NOT toggle
        XCTAssertEqual(root.activeSlot, 0)
        // Current slot updated in-place
        XCTAssertEqual(root.slots[0]?.keyPath, 200)
    }

    func testAlternatingSlotTransitions() {
        let root = NavigationRoot(item: makeDummyItem(keyPath: 1))

        // A→B: slot 0→1
        root.updateItem(makeDummyItem(keyPath: 2), animation: .easeIn, transition: .opacity, bringToFront: true)
        XCTAssertEqual(root.activeSlot, 1)
        XCTAssertEqual(root.slots[1]?.keyPath, 2)

        // B→C: slot 1→0
        root.updateItem(makeDummyItem(keyPath: 3), animation: .easeIn, transition: .opacity, bringToFront: true)
        XCTAssertEqual(root.activeSlot, 0)
        XCTAssertEqual(root.slots[0]?.keyPath, 3)

        // C→D: slot 0→1
        root.updateItem(makeDummyItem(keyPath: 4), animation: .easeIn, transition: .opacity, bringToFront: true)
        XCTAssertEqual(root.activeSlot, 1)
        XCTAssertEqual(root.slots[1]?.keyPath, 4)
    }

    func testSlotZIndexAssignment() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem(keyPath: 1),
            animation: .easeInOut,
            transition: .opacity,
            bringToFront: true
        )

        // Old slot (0) should have old zIndex (0), new slot (1) should have new zIndex (1)
        XCTAssertEqual(root.slotZIndex[0], 0)
        XCTAssertEqual(root.slotZIndex[1], 1)
    }

    func testMultipleBringToFrontAccumulatesZIndex() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(makeDummyItem(keyPath: 1), animation: .easeIn, transition: .opacity, bringToFront: true)
        root.updateItem(makeDummyItem(keyPath: 2), animation: .easeIn, transition: .opacity, bringToFront: true)
        root.updateItem(makeDummyItem(keyPath: 3), animation: .easeIn, transition: .opacity, bringToFront: false)

        XCTAssertEqual(root.zIndex, 1) // +1, +1, -1 = 1
    }
}
