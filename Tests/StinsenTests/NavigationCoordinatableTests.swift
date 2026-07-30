//
//  NavigationCoordinatableTests.swift
//  StinsenTests
//
//  Comprehensive unit tests for NavigationCoordinatable public API
//

import XCTest
@testable import Stinsen
import SwiftUI

@MainActor
final class NavigationCoordinatableTests: XCTestCase {

    var coordinator: TestNavigationCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = TestNavigationCoordinator()
        coordinator.setupRoot()
    }

    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }

    // MARK: - Stack Management Tests

    func testInitialStackIsEmpty() {
        XCTAssertEqual(coordinator.stack.value.count, 0)
        XCTAssertEqual(coordinator.stack.currentRoute, -1)
    }

    func testRouteToViewAppendsToStack() {
        // When
        coordinator.route(to: \.detailView)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
    }

    func testRouteToCoordinatorAppendsToStack() {
        // When
        let childCoordinator = coordinator.route(to: \.childCoordinator)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertNotNil(childCoordinator)
    }

    func testRouteToOpaqueCoordinatorAppendsToStack() {
        // When — uses `some Coordinatable` return type (type-erased to AnyCoordinator)
        let child = coordinator.route(to: \.opaqueChild)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertNotNil(child)
        XCTAssertNotNil(child.parent)
    }

    func testRouteWithInputPassesCorrectValue() {
        // Given
        let testInput = "Test Value"

        // When
        coordinator.route(to: \.detailWithInput, testInput)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertEqual(coordinator.stack.value.first?.input as? String, testInput)
    }

    func testPopToRootClearsStack() {
        // Given
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)
        XCTAssertEqual(coordinator.stack.value.count, 2)

        // When
        coordinator.popToRoot(nil)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 0)
    }

    func testPopToRootStoresCompletionAction() {
        // Given
        coordinator.route(to: \.detailView)
        XCTAssertEqual(coordinator.stack.value.count, 1)
        let bottomRemovedUid = coordinator.stack.value[0].uid

        // When
        coordinator.popToRoot {
            // Completion would be called by PresentationController during UIKit dismissal
        }

        // Then - stack is cleared; completion is keyed to the bottom-most removed item
        XCTAssertEqual(coordinator.stack.value.count, 0)
        XCTAssertNotNil(coordinator.stack.dismissalAction[bottomRemovedUid])
    }

    // MARK: - Focus Tests

    func testFocusFirstFindsExistingRoute() throws {
        // Given
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)

        // When
        try coordinator.focusFirst(\.detailView)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
    }

    func testFocusFirstThrowsWhenRouteNotFound() {
        // Given
        coordinator.route(to: \.secondDetailView)

        // Then
        XCTAssertThrowsError(try coordinator.focusFirst(\.detailView)) { error in
            XCTAssertTrue(error is FocusError)
        }
    }

    // MARK: - Root Management Tests

    func testRootSwitchesRootView() {
        // Given
        let root = coordinator.stack.root!
        let initialKeyPath = root.slots[root.activeSlotIndex].item.keyPath

        // When
        coordinator.root(\.alternativeRoot)

        // Then
        XCTAssertNotEqual(root.slots[root.activeSlotIndex].item.keyPath, initialKeyPath)
    }

    // MARK: - Animated Root Transition Tests

    func testAnimatedRootSwitchChangesActiveSlot() {
        // Given
        let initialSlot = coordinator.stack.root.activeSlotIndex

        // When — animation passed at call site
        coordinator.root(\.animatedRoot, animation: .easeInOut)

        // Then — animated transition → activeSlotIndex toggled
        XCTAssertNotEqual(coordinator.stack.root.activeSlotIndex, initialSlot)
    }

    func testAnimatedRootSwitchUpdatesZIndex() {
        // Given
        let initialZIndex = coordinator.stack.root.zIndex

        // When
        coordinator.root(\.animatedRoot, animation: .easeInOut)

        // Then — animated transition → zIndex +1
        XCTAssertEqual(coordinator.stack.root.zIndex, initialZIndex + 1)
    }

    func testNonAnimatedRootDoesNotChangeActiveSlot() {
        // When — no animation at call site
        coordinator.root(\.alternativeRoot)

        // Then — non-animated root → activeSlotIndex stays 0
        XCTAssertEqual(coordinator.stack.root.activeSlotIndex, 0)
    }

    func testNonAnimatedRootDoesNotChangeZIndex() {
        // Given
        let initialZIndex = coordinator.stack.root.zIndex

        // When
        coordinator.root(\.alternativeRoot)

        // Then
        XCTAssertEqual(coordinator.stack.root.zIndex, initialZIndex)
    }

    // MARK: - Parent-Child Relationship Tests

    func testChildCoordinatorHasCorrectParent() {
        // When
        let child = coordinator.route(to: \.childCoordinator)

        // Then
        XCTAssertNotNil(child.parent)
    }

    func testDismissChildRemovesFromStack() {
        // Given
        let child = coordinator.route(to: \.childCoordinator)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        // When
        coordinator.dismissChild(coordinator: child)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 0)
    }

    // MARK: - Stack State Tests

    func testCurrentRouteReturnsTopOfStack() {
        // Given
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)

        // Then
        XCTAssertNotEqual(coordinator.stack.currentRoute, -1)
    }

    // MARK: - disappear() Regression Tests (UI gesture double-dismiss bug)

    func testDisappear_withTwoItemStack_onlyRemovesChild() {
        // Regression: UI gesture dismiss of stack[1] was incorrectly also removing stack[0],
        // causing a double-dismiss of the parent VC.
        //
        // Given: stack = [A, B]
        coordinator.route(to: \.detailView)        // stack[0] = A
        coordinator.route(to: \.secondDetailView)  // stack[1] = B
        XCTAssertEqual(coordinator.stack.value.count, 2)
        let bUid = coordinator.stack.value[1].uid

        // When: B dismissed by UI gesture — its removal report arrives
        coordinator.disappear(deadUid: bUid)

        // Then: only B (stack[1]) is removed; A (stack[0]) must remain
        XCTAssertEqual(coordinator.stack.value.count, 1,
            "UI gesture dismiss of child must NOT remove parent from stack")
    }

    func testDisappear_withOneItemStack_clearsStack() {
        // Given: stack = [A]
        coordinator.route(to: \.detailView)
        XCTAssertEqual(coordinator.stack.value.count, 1)
        let aUid = coordinator.stack.value[0].uid

        // When: A dismissed by UI gesture — its removal report arrives
        coordinator.disappear(deadUid: aUid)

        // Then: stack is empty
        XCTAssertEqual(coordinator.stack.value.count, 0)
    }

    func testDisappear_afterProgrammaticPop_isNoOp() {
        // Regression: after a programmatic popLast removes B, B's removal report
        // still arrives later. This must be a no-op and must NOT remove A.
        //
        // Given: stack = [A, B] → programmatic pop → stack = [A]
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)
        let bUid = coordinator.stack.value[1].uid
        coordinator.popLast()
        XCTAssertEqual(coordinator.stack.value.count, 1)

        // When: B's late removal report arrives (ledger already recorded the pop)
        coordinator.disappear(deadUid: bUid)

        // Then: A is NOT removed — the dead uid is no longer in the stack, so no cleanup
        XCTAssertEqual(coordinator.stack.value.count, 1,
            "disappear() after programmatic pop must be a no-op")
    }

    func testDisappear_withThreeItemStack_onlyRemovesDirectChild() {
        // Given: stack = [A, B, C]
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)
        coordinator.route(to: \.detailView)
        XCTAssertEqual(coordinator.stack.value.count, 3)
        let cUid = coordinator.stack.value[2].uid

        // When: C (stack[2]) dismissed by UI gesture — its removal report arrives
        coordinator.disappear(deadUid: cUid)

        // Then: only C removed; A and B remain
        XCTAssertEqual(coordinator.stack.value.count, 2,
            "Only the directly dismissed child must be removed from the stack")
    }

    // MARK: - Identity Guard Tests (S15 — same-tick pop+push slot reuse)

    func testDisappear_lateReportAfterSlotReuse_doesNotEvictNewcomer() {
        // S15: pop then same-tick re-push reuses slot 0. The old tenant's death report
        // arrives after the newcomer moved in — it must not evict the newcomer.
        //
        // Given: A1 pushed → popped → A2 pushed into the same slot
        coordinator.route(to: \.detailView)                   // A1
        let a1Uid = coordinator.stack.value[0].uid
        coordinator.popLast()                                  // ledger: []
        coordinator.route(to: \.detailView)                   // A2 — same route, same slot
        let a2Uid = coordinator.stack.value[0].uid
        XCTAssertNotEqual(a1Uid, a2Uid, "each push must mint its own identity")

        // When: A1's late removal report arrives (transition finished after A2's push)
        coordinator.disappear(deadUid: a1Uid)

        // Then: A2 survives — the report names A1, and A1 is no longer in the stack
        XCTAssertEqual(coordinator.stack.value.count, 1,
            "a late report must never evict the slot's new tenant")
        XCTAssertEqual(coordinator.stack.value[0].uid, a2Uid)
    }

    func testDisappear_lateReportAfterSlotReuse_runsOnlyDeadItemsCallbacks() {
        // S15 companion: the late report must consume exactly the dead item's callbacks —
        // the newcomer's onDismiss must survive untouched.
        var fired: [String] = []

        coordinator.route(to: \.detailView, onDismiss: { fired.append("A1") })
        let a1Uid = coordinator.stack.value[0].uid
        coordinator.popLast()
        coordinator.route(to: \.detailView, onDismiss: { fired.append("A2") })
        let a2Uid = coordinator.stack.value[0].uid

        // When: A1's late report arrives
        coordinator.disappear(deadUid: a1Uid)

        // Then: only A1's callback fired; A2's stays registered for its own death
        XCTAssertEqual(fired, ["A1"])
        XCTAssertNotNil(coordinator.stack.dismissalAction[a2Uid])
    }

    func testDismissalActions_onDismissAndPopCompletion_bothFire() {
        // Known original defect (answer sheet S1): pop completion used to overwrite the
        // route-time onDismiss under the same index key. With uid keys both coexist.
        var fired: [String] = []

        coordinator.route(to: \.detailView, onDismiss: { fired.append("onDismiss") })
        let uid = coordinator.stack.value[0].uid
        coordinator.popLast { fired.append("completion") }

        // When: the removal report arrives
        coordinator.disappear(deadUid: uid)

        // Then: both callbacks fire, in registration order
        XCTAssertEqual(fired, ["onDismiss", "completion"])
    }

    func testRouteOnDismiss_duplicatePushDropped_doesNotRegisterCallback() {
        // The duplicate-push guard silently drops a consecutive push of the same route
        // (e.g. a double-tap). Its onDismiss must not attach to the existing instance —
        // otherwise that screen's close would fire callbacks twice.
        coordinator.route(to: \.detailView)
        let existingUid = coordinator.stack.value[0].uid

        coordinator.route(to: \.detailView, onDismiss: { })

        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertNil(coordinator.stack.dismissalAction[existingUid],
            "a dropped push must not attach its onDismiss to the surviving instance")
    }

    // MARK: - Memory Management Tests

    func testWeakParentReference() {
        // Given
        var parent: TestNavigationCoordinator? = TestNavigationCoordinator()
        weak var weakParent = parent
        let child = parent!.route(to: \.childCoordinator)

        // When
        parent = nil

        // Then
        XCTAssertNil(weakParent)
        XCTAssertNil(child.parent)
    }

    func testCoordinatorDeallocation() {
        // Given
        weak var weakChild: AnyCoordinator?

        autoreleasepool {
            let parent = TestNavigationCoordinator()
            let child = parent.route(to: \.childCoordinator)
            weakChild = child
            XCTAssertNotNil(weakChild)

            // When
            parent.dismissChild(coordinator: child)
        }

        // Then - child should be deallocated
        XCTAssertNil(weakChild)
    }
}

// MARK: - Test Helpers

@MainActor
final class TestNavigationCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<TestNavigationCoordinator>(initial: \.mainView)

    @Root var mainView = makeMainView
    @Route(.push) var detailView = makeDetailView
    @Route(.push) var secondDetailView = makeSecondDetailView
    @Route(.push) var detailWithInput = makeDetailWithInput
    @Route(.push) var childCoordinator = makeChildCoordinator
    @Route(.push) var opaqueChild = makeOpaqueChild
    @Root var alternativeRoot = makeAlternativeRoot
    @Root var animatedRoot = makeAnimatedRoot

    func makeMainView() -> some View {
        Text("Main")
    }

    func makeDetailView() -> some View {
        Text("Detail")
    }

    func makeSecondDetailView() -> some View {
        Text("Second Detail")
    }

    func makeDetailWithInput(_ input: String) -> some View {
        Text("Detail: \(input)")
    }

    func makeChildCoordinator() -> TestChildCoordinator {
        TestChildCoordinator()
    }

    func makeOpaqueChild() -> some Coordinatable {
        TestChildCoordinator()
    }

    func makeAlternativeRoot() -> some View {
        Text("Alternative Root")
    }

    func makeAnimatedRoot() -> some View {
        Text("Animated Root")
    }
}

@MainActor
final class TestChildCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<TestChildCoordinator>(initial: \.childMain)

    @Root var childMain = makeChildMain

    func makeChildMain() -> some View {
        Text("Child Main")
    }
}
