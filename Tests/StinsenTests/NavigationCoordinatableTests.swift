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

        // When
        coordinator.popToRoot {
            // Completion would be called by PresentationController during UIKit dismissal
        }

        // Then - stack is cleared and dismissal action is stored
        XCTAssertEqual(coordinator.stack.value.count, 0)
        XCTAssertNotNil(coordinator.stack.dismissalAction[-1])
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
        let initialKeyPath = coordinator.stack.root.item.keyPath

        // When
        coordinator.root(\.alternativeRoot)

        // Then
        XCTAssertNotEqual(coordinator.stack.root.item.keyPath, initialKeyPath)
    }

    func testIsRootReturnsTrueForCurrentRoot() {
        // Given
        coordinator.root(\.alternativeRoot)

        // Then
        XCTAssertTrue(coordinator.isRoot(\.alternativeRoot))
        XCTAssertFalse(coordinator.isRoot(\.mainView))
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
        weak var weakChild: TestChildCoordinator?

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
    let stack = Stinsen.NavigationStack<TestNavigationCoordinator>(initial: \.mainView)

    @Root var mainView = makeMainView
    @Route(.push) var detailView = makeDetailView
    @Route(.push) var secondDetailView = makeSecondDetailView
    @Route(.push) var detailWithInput = makeDetailWithInput
    @Route(.push) var childCoordinator = makeChildCoordinator
    @Root var alternativeRoot = makeAlternativeRoot

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

    func makeAlternativeRoot() -> some View {
        Text("Alternative Root")
    }
}

@MainActor
final class TestChildCoordinator: NavigationCoordinatable {
    let stack = Stinsen.NavigationStack<TestChildCoordinator>(initial: \.childMain)

    @Root var childMain = makeChildMain

    func makeChildMain() -> some View {
        Text("Child Main")
    }
}
