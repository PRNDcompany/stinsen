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

    func testPopToRootRunsItsCompletion() {
        // Given
        coordinator.route(to: \.detailView)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        // When
        var completed = false
        coordinator.popToRoot { completed = true }

        // Then — the completion runs when the rewind is done, rather than being filed
        // under an index for some later dismissal callback to look up.
        XCTAssertEqual(coordinator.stack.value.count, 0)
        XCTAssertTrue(completed)
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

    // MARK: - Reconcile regressions (screens closed by something other than us)

    // These were `disappear(_ id:)` tests. The mechanism they covered is gone — an index
    // arriving from a per-level presentation controller, with the coordinator inferring
    // from it how much to remove — and it is the mechanism that caused the bug they were
    // written for (`7b1cac0`: dismissing the child also popped the parent).
    //
    // What has to stay true survives the rewrite unchanged: **a screen closed by a UI
    // gesture takes itself off the stack and nothing else.** Now that is answered by
    // asking UIKit rather than by arithmetic, so these drive a real navigation
    // controller and close screens behind the coordinator's back.

    /// Routes `count` screens onto a live navigation controller, one settled transition
    /// at a time.
    private func pushSettled(
        _ routes: [KeyPath<TestNavigationCoordinator, Stinsen.Transition<TestNavigationCoordinator, Presentation, Void, AnyView>>],
        on fixture: HostFixture
    ) {
        for route in routes {
            coordinator.route(to: route)
            fixture.settle()
        }
    }

    func testReconcile_afterExternalPopOfTheTopScreen_keepsTheOneBelow() {
        let fixture = HostFixture(coordinator: coordinator)
        pushSettled([\.detailView, \.secondDetailView], on: fixture)  // A, B
        XCTAssertEqual(coordinator.stack.value.count, 2)

        fixture.navigation.popViewController(animated: false)
        fixture.settle()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 1,
            "closing the child must not take the parent with it")
    }

    func testReconcile_afterExternalPopOfTheOnlyScreen_emptiesTheStack() {
        let fixture = HostFixture(coordinator: coordinator)
        pushSettled([\.detailView], on: fixture)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        fixture.navigation.popViewController(animated: false)
        fixture.settle()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 0)
    }

    /// A late callback for a screen we already removed used to pop again. Reconciling is
    /// idempotent by construction — it re-derives rather than stepping.
    func testReconcile_afterProgrammaticPop_isANoOp() {
        let fixture = HostFixture(coordinator: coordinator)
        pushSettled([\.detailView, \.secondDetailView], on: fixture)
        coordinator.popLast()
        fixture.settle()
        XCTAssertEqual(coordinator.stack.value.count, 1)

        coordinator.host.reconcile()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 1)
    }

    func testReconcile_afterExternalPop_removesOnlyWhatUIKitRemoved() {
        let fixture = HostFixture(coordinator: coordinator)
        pushSettled([\.detailView, \.secondDetailView, \.detailView], on: fixture)
        XCTAssertEqual(coordinator.stack.value.count, 3)

        fixture.navigation.popViewController(animated: false)
        fixture.settle()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 2)
    }

    /// Each screen's `onDismiss` runs once and only once, whichever side closed it.
    func testReconcile_firesOnDismissExactlyOnceForAnExternallyClosedScreen() {
        let fixture = HostFixture(coordinator: coordinator)
        var fired = 0
        coordinator.route(.push, to: Text("detail"), onDismiss: { fired += 1 })
        fixture.settle()

        fixture.navigation.popViewController(animated: false)
        fixture.settle()
        coordinator.host.reconcile()
        coordinator.host.reconcile()

        XCTAssertEqual(fired, 1)
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

// MARK: - Back-to-back navigation

/// Two navigation calls in the same run loop tick.
///
/// This is what an app does when a completion handler routes straight after another
/// navigation, and UIKit discards the second one: `pushViewController` issued while a
/// push is still animating simply does nothing. It used to survive by accident — each
/// stack level had its own presentation controller that could not act until its view
/// controller had been introspected, which happened to be after the transition — and
/// that accident is gone, so the host has to serialise them deliberately.
@MainActor
final class BackToBackNavigationTests: XCTestCase {

    var coordinator: TestNavigationCoordinator!
    var fixture: HostFixture!

    override func setUp() {
        super.setUp()
        coordinator = TestNavigationCoordinator()
        coordinator.setupRoot()
        fixture = HostFixture(coordinator: coordinator)
    }

    override func tearDown() {
        fixture = nil
        coordinator = nil
        super.tearDown()
    }

    func testPushThenPush_bothScreensArrive() {
        coordinator.route(.push, to: Text("first"))
        coordinator.route(.push, to: Text("second"))

        fixture.settle(2)

        XCTAssertEqual(coordinator.stack.value.count, 2)
        XCTAssertEqual(coordinator.stack.value.compactMap(\.viewController).count, 2,
            "both screens must have reached UIKit")
        XCTAssertEqual(fixture.navigation.viewControllers.count, 3,
            "root plus two pushed screens")
    }

    // Presentations are not covered here, deliberately. In a bare XCTest host the
    // presentation animation never completes — the presented screen stays
    // `isBeingPresented` forever and never receives `viewDidAppear` — so a modal test
    // would be measuring the fixture rather than the coordinator. `PushThenPresent`,
    // `PresentThenPush` and `PresentThenPresent` are covered by the UI tests, which run
    // against a real app and a real run loop.
}
