import XCTest
import SwiftUI
@testable import Stinsen

@MainActor
final class NavigationRootTests: XCTestCase {

    /// Named rather than declared: these tests are about slot mechanics, and a name is
    /// the cheapest distinct identity to give two items that must not be confused.
    private func makeDummyItem(_ name: String = "0") -> NavigationRootItem {
        NavigationRootItem(route: .named(name), input: nil, child: AnyView(EmptyView()))
    }

    // MARK: - updateItem with animation

    func testUpdateItemWithAnimationChangesActiveSlot() {
        let root = NavigationRoot(item: makeDummyItem())
        XCTAssertEqual(root.activeSlotIndex, 0)

        root.updateItem(
            makeDummyItem("1"),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        XCTAssertEqual(root.activeSlotIndex, 1)
    }

    func testUpdateItemWithAnimationAddsSecondSlot() {
        let root = NavigationRoot(item: makeDummyItem())
        XCTAssertEqual(root.slots.count, 1)

        root.updateItem(
            makeDummyItem("1"),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        XCTAssertEqual(root.slots.count, 2)
    }

    func testZIndexIncrementsOnAnimatedTransition() {
        let root = NavigationRoot(item: makeDummyItem())
        let initialZIndex = root.zIndex

        root.updateItem(
            makeDummyItem("1"),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        XCTAssertEqual(root.zIndex, initialZIndex + 1)
    }

    func testUpdateItemWithoutAnimationDoesNotChangeActiveSlot() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem("1"),
            animation: nil,
            transition: .identity,
            zOrder: .front
        )

        XCTAssertEqual(root.activeSlotIndex, 0)
    }

    // MARK: - Two-Slot behavior

    func testInitialActiveSlotIndexIsZero() {
        let root = NavigationRoot(item: makeDummyItem())
        XCTAssertEqual(root.activeSlotIndex, 0)
    }

    func testInitialSlotZeroHasItem() {
        let root = NavigationRoot(item: makeDummyItem("42"))
        XCTAssertNotNil(root.slots[0].item)
        XCTAssertEqual(root.slots[0].item.route, .named("42"))
    }

    func testActiveSlotTogglesOnAnimatedTransition() {
        let root = NavigationRoot(item: makeDummyItem())
        XCTAssertEqual(root.activeSlotIndex, 0)

        root.updateItem(
            makeDummyItem("1"),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        XCTAssertEqual(root.activeSlotIndex, 1)
    }

    func testSlotsPreserveContentDuringTransition() {
        let root = NavigationRoot(item: makeDummyItem("100"))

        root.updateItem(
            makeDummyItem("200"),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        // Old slot still has A, new slot has B
        XCTAssertEqual(root.slots[0].item.route, .named("100"))
        XCTAssertEqual(root.slots[1].item.route, .named("200"))
    }

    func testNonAnimatedTransitionUpdatesSameSlot() {
        let root = NavigationRoot(item: makeDummyItem("100"))
        XCTAssertEqual(root.activeSlotIndex, 0)

        root.updateItem(
            makeDummyItem("200"),
            animation: nil,
            transition: .identity,
            zOrder: .front
        )

        // activeSlotIndex should NOT toggle
        XCTAssertEqual(root.activeSlotIndex, 0)
        // Current slot updated in-place
        XCTAssertEqual(root.slots[0].item.route, .named("200"))
    }

    func testAlternatingSlotTransitions() {
        let root = NavigationRoot(item: makeDummyItem("1"))

        // A→B: slot 0→1
        root.updateItem(makeDummyItem("2"), animation: .easeIn, transition: .opacity, zOrder: .front)
        XCTAssertEqual(root.activeSlotIndex, 1)
        XCTAssertEqual(root.slots[1].item.route, .named("2"))

        // B→C: slot 1→0
        root.updateItem(makeDummyItem("3"), animation: .easeIn, transition: .opacity, zOrder: .front)
        XCTAssertEqual(root.activeSlotIndex, 0)
        XCTAssertEqual(root.slots[0].item.route, .named("3"))

        // C→D: slot 0→1
        root.updateItem(makeDummyItem("4"), animation: .easeIn, transition: .opacity, zOrder: .front)
        XCTAssertEqual(root.activeSlotIndex, 1)
        XCTAssertEqual(root.slots[1].item.route, .named("4"))
    }

    // MARK: - zOrder

    func testSlotZIndexFront() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem("1"),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .front
        )

        // .front: new slot (1) gets higher zIndex (comes to front)
        XCTAssertEqual(root.slots[0].zIndex, 0)  // old slot: unchanged
        XCTAssertEqual(root.slots[1].zIndex, 1)  // new slot: higher (front)
    }

    func testSlotZIndexBack() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(
            makeDummyItem("1"),
            animation: .easeInOut,
            transition: .opacity,
            zOrder: .back
        )

        // .back: new slot gets lower zIndex (goes behind old slot)
        XCTAssertEqual(root.slots[1].zIndex, -1)  // new slot: lower (behind)
        XCTAssertEqual(root.slots[0].zIndex, 0)   // old slot: unchanged (stays in front)
    }

    func testMultipleAnimatedTransitionsAccumulateZIndex() {
        let root = NavigationRoot(item: makeDummyItem())

        root.updateItem(makeDummyItem("1"), animation: .easeIn, transition: .opacity, zOrder: .front)
        root.updateItem(makeDummyItem("2"), animation: .easeIn, transition: .opacity, zOrder: .front)
        root.updateItem(makeDummyItem("3"), animation: .easeIn, transition: .opacity, zOrder: .front)

        XCTAssertEqual(root.zIndex, 3) // +1, +1, +1 = 3
    }
}
