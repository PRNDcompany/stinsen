//
//  NavigationStackTests.swift
//  StinsenTests
//
//  What a coordinator records, and what rewinding removes.
//
//  These used to drive `CoordinatorStack` directly — `push`, `popToIndex`, the Combine
//  publishers, the `dismissalAction` dictionary. All of that was the depth-index
//  machinery, and it is gone: screens are recorded by `NavigationHost` and their order
//  is read back from UIKit. So the tests now go through the coordinator API, which is
//  the only way in that still exists.
//
//  No view controllers are involved here, so no host is bound. That is the deliberate
//  "recorded but not yet on screen" case: routing during a deep link, before the first
//  render, has to behave exactly like routing afterwards.
//

import XCTest
@testable import Stinsen
import SwiftUI
import Combine

@MainActor
final class NavigationStackTests: XCTestCase {

    var coordinator: TestStackCoordinator!
    var stack: CoordinatorStack<TestStackCoordinator>!

    override func setUp() {
        super.setUp()
        coordinator = TestStackCoordinator()
        stack = coordinator.stack
    }

    override func tearDown() {
        stack = nil
        coordinator = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitialStackIsEmpty() {
        XCTAssertEqual(stack.value.count, 0)
        XCTAssertNil(stack.currentRouteKey)
    }

    func testInitialRouteIsSet() {
        XCTAssertNotNil(stack.initial)
    }

    // MARK: - Recording

    func testRouteRecordsAScreen() {
        coordinator.route(to: \.first)

        XCTAssertEqual(stack.value.count, 1)
        XCTAssertEqual(stack.currentRouteKey, .declared(\TestStackCoordinator.first))
    }

    /// Consecutive entry into the same route is a real drill-down (product → related
    /// product → product), and it used to be dropped on the floor because `push`
    /// compared the new item's route against the current top.
    func testConsecutiveSameRouteRecordsBothScreens() {
        coordinator.route(to: \.withInput, "a")
        coordinator.route(to: \.withInput, "b")

        XCTAssertEqual(stack.value.count, 2)
        XCTAssertEqual(stack.value.map { $0.input as? String }, ["a", "b"])
    }

    func testImperativeRoutesAreDistinctEvenWithTheSameContent() {
        coordinator.route(.push, to: Text("x"))
        coordinator.route(.push, to: Text("x"))

        XCTAssertEqual(stack.value.count, 2)
        XCTAssertNotEqual(stack.value[0].route, stack.value[1].route)
    }

    // MARK: - Rewinding

    func testPopLastRemovesOnlyTheTopScreen() {
        coordinator.route(to: \.first)
        coordinator.route(to: \.second)

        coordinator.popLast()

        XCTAssertEqual(stack.value.count, 1)
        XCTAssertEqual(stack.currentRouteKey, .declared(\TestStackCoordinator.first))
    }

    func testPopLastOnAnEmptyStackDoesNothing() {
        coordinator.popLast()

        XCTAssertEqual(stack.value.count, 0)
    }

    func testPopToRootClearsEverything() {
        coordinator.route(to: \.first)
        coordinator.route(to: \.second)
        coordinator.route(to: \.withInput, "x")

        coordinator.popToRoot()

        XCTAssertEqual(stack.value.count, 0)
        XCTAssertNil(stack.currentRouteKey)
    }

    /// `route(_:to:id:)` names a screen so it can be returned to later — the gap
    /// between `popLast()` (one step) and `popToRoot()` (all the way).
    func testPopToIdRewindsToTheNamedScreen() {
        coordinator.route(.push, to: Text("list"), id: "list")
        coordinator.route(.push, to: Text("detail"))
        coordinator.route(.push, to: Text("related"))

        XCTAssertTrue(coordinator.popTo(id: "list"))

        XCTAssertEqual(stack.value.count, 1)
        XCTAssertEqual(stack.currentRouteKey?.name, "list")
    }

    /// The nearest match, not the first — "go back to the list" means the one you just
    /// came from. `focusFirst` deliberately does the opposite.
    func testPopToIdRewindsToTheNearestMatch() {
        coordinator.route(.push, to: Text("list 1"), id: "list")
        coordinator.route(.push, to: Text("detail"))
        coordinator.route(.push, to: Text("list 2"), id: "list")
        coordinator.route(.push, to: Text("related"))

        XCTAssertTrue(coordinator.popTo(id: "list"))

        XCTAssertEqual(stack.value.count, 3)
    }

    func testPopToUnknownIdReportsFailureAndChangesNothing() {
        coordinator.route(.push, to: Text("detail"))

        XCTAssertFalse(coordinator.popTo(id: "nope"))
        XCTAssertEqual(stack.value.count, 1)
    }

    // MARK: - onDismiss

    /// The closure belongs to the screen being opened, not to the one below it. Keying
    /// it by "current top index" is why routing from inside a dismissal handler used to
    /// be truncated by the very pop that triggered it.
    func testOnDismissFiresForTheScreenItWasAttachedTo() {
        var fired: [String] = []
        coordinator.route(.push, to: Text("a"), onDismiss: { fired.append("a") })
        coordinator.route(.push, to: Text("b"), onDismiss: { fired.append("b") })

        coordinator.popLast()
        XCTAssertEqual(fired, ["b"])

        coordinator.popLast()
        XCTAssertEqual(fired, ["b", "a"])
    }

    /// Deepest first: an `onDismiss` that navigates should see the stack it is landing
    /// on, not one still holding screens that are on their way out.
    func testMultiLevelRewindReportsDeepestFirst() {
        var fired: [String] = []
        coordinator.route(.push, to: Text("a"), onDismiss: { fired.append("a") })
        coordinator.route(.push, to: Text("b"), onDismiss: { fired.append("b") })
        coordinator.route(.push, to: Text("c"), onDismiss: { fired.append("c") })

        coordinator.popToRoot()

        XCTAssertEqual(fired, ["c", "b", "a"])
    }

    /// A screen opened from a dismissal handler has to survive the rewind that ran it.
    func testRoutingFromOnDismissSurvives() {
        coordinator.route(.push, to: Text("a"))
        coordinator.route(.push, to: Text("b"), id: "b", onDismiss: { [weak coordinator] in
            coordinator?.route(.push, to: Text("c"), id: "c")
        })

        coordinator.popLast()

        XCTAssertEqual(stack.value.map(\.route.name), [nil, "c"])
    }

    // MARK: - Queries

    func testIsInStackFindsADeclaredRoute() {
        coordinator.route(to: \.first)

        XCTAssertTrue(stack.isInStack(\TestStackCoordinator.first))
        XCTAssertFalse(stack.isInStack(\TestStackCoordinator.second))
    }

    /// The `Int` API is deprecated but still shipped, and the testbed reads it.
    func testDeprecatedHashBasedQueriesStillAnswer() {
        coordinator.route(to: \.first)

        XCTAssertEqual(stack.currentRoute, (\TestStackCoordinator.first).hashValue)
        XCTAssertTrue(stack.isInStack((\TestStackCoordinator.first).hashValue))

        coordinator.popToRoot()
        XCTAssertEqual(stack.currentRoute, -1)
    }

    // MARK: - NavigationRoot

    func testNavigationRootItemChildReference() {
        // Given
        let coordinator = TestStackCoordinator()
        let item = NavigationRootItem(
            keyPath: 123,
            input: "test",
            child: coordinator
        )

        // Then
        XCTAssertNotNil(item.child)
        XCTAssertEqual(item.keyPath, 123)
        XCTAssertEqual(item.input as? String, "test")
    }

    func testNavigationRootPublishesChanges() {
        // Given
        let coordinator = TestStackCoordinator()
        let item1 = NavigationRootItem(
            keyPath: 1,
            input: nil,
            child: coordinator
        )
        let root = NavigationRoot(item: item1)

        let expectation = XCTestExpectation(description: "Published change")
        let cancellable = root.objectWillChange.sink {
            expectation.fulfill()
        }

        // When
        let item2 = NavigationRootItem(
            keyPath: 2,
            input: nil,
            child: coordinator
        )
        root.updateItem(item2, animation: .easeInOut, transition: .identity, zOrder: .front)

        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
}

// MARK: - Test Helpers

@MainActor
final class TestStackCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<TestStackCoordinator>(initial: \.main)

    @Root var main = makeMain
    @Route(.push) var first = makeFirst
    @Route(.push) var second = makeSecond
    @Route(.push) var withInput = makeWithInput

    func makeMain() -> some View {
        Text("Main")
    }

    func makeFirst() -> some View {
        Text("First")
    }

    func makeSecond() -> some View {
        Text("Second")
    }

    func makeWithInput(_ input: String) -> some View {
        Text(input)
    }
}

@MainActor
class MockPresentationType: PresentationType {
    func makePresented<T: NavigationCoordinatable>(
        content: StackItemContent,
        nextId: Int,
        coordinator: T
    ) -> ViewControllerPresented? {
        return nil
    }

    func makeViewController<Content: View>(content: Content) -> UIViewController {
        return UIHostingController(rootView: content)
    }

    func presented(parent: UIViewController, content: UIViewController,
                   onAppeared: @escaping () -> Void, onDismissed: @escaping () -> Void) {}

    func dismissed(viewController: UIViewController) {}
}
