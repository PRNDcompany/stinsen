//
//  NavigationCoordinatableTests.swift
//  StinsenTests
//
//  Comprehensive unit tests for NavigationCoordinatable public API
//

import XCTest
@testable import Stinsen
import SwiftUI

final class NavigationCoordinatableTests: XCTestCase {
    
    var coordinator: TestNavigationCoordinator!
    
    override func setUp() {
        super.setUp()
        coordinator = TestNavigationCoordinator()
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
        XCTAssertEqual(coordinator.stack.currentRoute, TestNavigationCoordinator.detailView.hashValue)
    }
    
    func testRouteToCoordinatorAppendsToStack() {
        // When
        let childCoordinator = coordinator.route(to: \.childCoordinator)
        
        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertNotNil(childCoordinator)
        XCTAssertEqual(childCoordinator.parent?.id, coordinator.id)
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
    
    func testPopToRootCallsCompletionHandler() {
        // Given
        let expectation = XCTestExpectation(description: "Completion called")
        coordinator.route(to: \.detailView)
        
        // When
        coordinator.popToRoot {
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
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
        XCTAssertEqual(coordinator.stack.currentRoute, TestNavigationCoordinator.detailView.hashValue)
    }
    
    func testFocusFirstThrowsWhenRouteNotFound() {
        // Given
        coordinator.route(to: \.secondDetailView)
        
        // Then
        XCTAssertThrowsError(try coordinator.focusFirst(\.detailView)) { error in
            XCTAssertTrue(error is FocusError)
        }
    }
    
    func testFocusFirstWithInputMatching() throws {
        // Given
        coordinator.route(to: \.detailWithInput, "First")
        coordinator.route(to: \.detailWithInput, "Second")
        coordinator.route(to: \.secondDetailView)
        
        // When
        try coordinator.focusFirst(\.detailWithInput, "Second")
        
        // Then
        XCTAssertEqual(coordinator.stack.value.count, 2)
        XCTAssertEqual(coordinator.stack.value.last?.input as? String, "Second")
    }
    
    // MARK: - Root Management Tests
    
    func testRootSwitchesRootView() {
        // Given
        let initialKeyPath = coordinator.stack.root.item.keyPath
        
        // When
        coordinator.root(\.alternativeRoot)
        
        // Then
        XCTAssertNotEqual(coordinator.stack.root.item.keyPath, initialKeyPath)
        XCTAssertEqual(coordinator.stack.root.item.keyPath, TestNavigationCoordinator.alternativeRoot.hashValue)
    }
    
    func testIsRootReturnsTrueForCurrentRoot() {
        // Given
        coordinator.root(\.alternativeRoot)
        
        // Then
        XCTAssertTrue(coordinator.isRoot(\.alternativeRoot))
        XCTAssertFalse(coordinator.isRoot(\.mainView))
    }
    
    func testHasRootReturnsCoordinatorForMatchingRoot() {
        // Given
        let childCoordinator = coordinator.root(\.rootWithCoordinator)
        
        // Then
        let foundCoordinator = coordinator.hasRoot(\.rootWithCoordinator)
        XCTAssertNotNil(foundCoordinator)
        XCTAssertEqual(foundCoordinator?.id, childCoordinator.id)
    }
    
    // MARK: - Parent-Child Relationship Tests
    
    func testChildCoordinatorHasCorrectParent() {
        // When
        let child = coordinator.route(to: \.childCoordinator)
        
        // Then
        XCTAssertNotNil(child.parent)
        XCTAssertEqual(child.parent?.id, coordinator.id)
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
    
    func testDismissCoordinatorCallsParent() {
        // Given
        let parent = TestNavigationCoordinator()
        let child = parent.route(to: \.childCoordinator)
        
        // When
        child.dismissCoordinator(nil)
        
        // Then
        XCTAssertEqual(parent.stack.value.count, 0)
    }
    
    // MARK: - Stack State Tests
    
    func testIsInStackReturnsTrueForExistingRoute() {
        // Given
        coordinator.route(to: \.detailView)
        
        // Then
        XCTAssertTrue(coordinator.stack.isInStack(TestNavigationCoordinator.detailView.hashValue))
        XCTAssertFalse(coordinator.stack.isInStack(TestNavigationCoordinator.secondDetailView.hashValue))
    }
    
    func testCurrentRouteReturnsTopOfStack() {
        // Given
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)
        
        // Then
        XCTAssertEqual(coordinator.stack.currentRoute, TestNavigationCoordinator.secondDetailView.hashValue)
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

final class TestNavigationCoordinator: NavigationCoordinatable {
    let stack = NavigationStack<TestNavigationCoordinator>(initial: \.mainView)
    weak var parent: ChildDismissable?
    
    @Route(.push) var mainView = makeMainView
    @Route(.push) var detailView = makeDetailView
    @Route(.push) var secondDetailView = makeSecondDetailView
    @Route(.push) var detailWithInput = makeDetailWithInput
    @Route(.push) var childCoordinator = makeChildCoordinator
    @Route(.root) var alternativeRoot = makeAlternativeRoot
    @Route(.root) var rootWithCoordinator = makeRootCoordinator
    
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
    
    func makeRootCoordinator() -> TestChildCoordinator {
        TestChildCoordinator()
    }
}

final class TestChildCoordinator: NavigationCoordinatable {
    let stack = NavigationStack<TestChildCoordinator>(initial: \.childMain)
    weak var parent: ChildDismissable?
    
    @Route(.push) var childMain = makeChildMain
    
    func makeChildMain() -> some View {
        Text("Child Main")
    }
}