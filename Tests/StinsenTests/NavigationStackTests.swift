//
//  NavigationStackTests.swift
//  StinsenTests
//
//  Unit tests for NavigationStack functionality
//

import XCTest
@testable import Stinsen
import SwiftUI
import Combine

@MainActor
final class NavigationStackTests: XCTestCase {

    var coordinator: TestStackCoordinator!
    var stack: Stinsen.NavigationStack<TestStackCoordinator>!

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

    // MARK: - Initialization Tests

    func testInitialStackIsEmpty() {
        XCTAssertEqual(stack.value.count, 0)
        XCTAssertEqual(stack.currentRoute, -1)
    }

    func testInitialRouteIsSet() {
        XCTAssertNotNil(stack.initial)
    }

    // MARK: - Push Tests

    func testPushAddsItemToStack() {
        // Given
        let item = NavigationStackItem(
            presentationType: MockPresentationType(),
            content: .view(AnyView(Text("Test"))),
            keyPath: 123,
            input: nil
        )

        // When
        stack.push(item)

        // Then
        XCTAssertEqual(stack.value.count, 1)
        XCTAssertEqual(stack.value.first?.keyPath, 123)
    }

    func testPushIgnoresDuplicateConsecutivePushes() {
        // Given
        let item1 = NavigationStackItem(
            presentationType: MockPresentationType(),
            content: .view(AnyView(Text("Test"))),
            keyPath: 123,
            input: nil
        )

        // When
        stack.push(item1)
        stack.push(item1) // Same keyPath

        // Then
        XCTAssertEqual(stack.value.count, 1)
    }

    func testPushPublishesViaValuePublisher() {
        // Given
        let expectation = XCTestExpectation(description: "valuePublisher emitted")
        var receivedItems: [NavigationStackItem] = []

        let cancellable = stack.valuePublisher
            .dropFirst() // Skip initial empty value
            .sink { items in
                receivedItems = items
                expectation.fulfill()
            }

        let item = NavigationStackItem(
            presentationType: MockPresentationType(),
            content: .view(AnyView(Text("Test"))),
            keyPath: 123,
            input: nil
        )

        // When
        stack.push(item)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedItems.count, 1)
        cancellable.cancel()
    }

    // MARK: - Pop Tests

    func testPopToIndexRemovesItems() {
        // Given
        for i in 0..<5 {
            let item = NavigationStackItem(
                presentationType: MockPresentationType(),
                content: .view(AnyView(Text("Item \(i)"))),
                keyPath: i,
                input: nil
            )
            stack.push(item)
        }

        // When
        stack.popToIndex(2)

        // Then
        XCTAssertEqual(stack.value.count, 3)
        XCTAssertEqual(stack.value.last?.keyPath, 2)
    }

    func testPopToIndexMinusOneClearsStack() {
        // Given
        for i in 0..<3 {
            let item = NavigationStackItem(
                presentationType: MockPresentationType(),
                content: .view(AnyView(Text("Item \(i)"))),
                keyPath: i,
                input: nil
            )
            stack.push(item)
        }

        // When
        stack.popToIndex(-1)

        // Then
        XCTAssertEqual(stack.value.count, 0)
    }

    func testPopToIndexPublishesViaPoppedPublisher() {
        // Given
        let expectation = XCTestExpectation(description: "poppedPublisher emitted")
        var poppedIndex: Int?

        let cancellable = stack.poppedPublisher
            .sink { index in
                poppedIndex = index
                expectation.fulfill()
            }

        let item = NavigationStackItem(
            presentationType: MockPresentationType(),
            content: .view(AnyView(Text("Test"))),
            keyPath: 123,
            input: nil
        )
        stack.push(item)

        // When
        stack.popToIndex(0)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(poppedIndex, 0)
        cancellable.cancel()
    }

    func testPopToIndexOutOfBoundsIsIgnored() {
        // Given
        let item = NavigationStackItem(
            presentationType: MockPresentationType(),
            content: .view(AnyView(Text("Test"))),
            keyPath: 123,
            input: nil
        )
        stack.push(item)

        // When
        stack.popToIndex(10) // Out of bounds

        // Then
        XCTAssertEqual(stack.value.count, 1) // No change
    }

    // MARK: - Stack State Tests

    func testCurrentRouteReturnsLastItemKeyPath() {
        // Given
        for i in 0..<3 {
            let item = NavigationStackItem(
                presentationType: MockPresentationType(),
                content: .view(AnyView(Text("Item \(i)"))),
                keyPath: i * 100,
                input: nil
            )
            stack.push(item)
        }

        // Then
        XCTAssertEqual(stack.currentRoute, 200)
    }

    func testIsInStackFindsExistingKeyPath() {
        // Given
        let item = NavigationStackItem(
            presentationType: MockPresentationType(),
            content: .view(AnyView(Text("Test"))),
            keyPath: 999,
            input: nil
        )
        stack.push(item)

        // Then
        XCTAssertTrue(stack.isInStack(999))
        XCTAssertFalse(stack.isInStack(111))
    }

    // MARK: - Dismissal Action Tests

    func testDismissalActionIsStored() {
        // Given
        let expectation = XCTestExpectation(description: "Dismissal action called")

        stack.dismissalAction[0] = {
            expectation.fulfill()
        }

        // When
        stack.dismissalAction[0]?()

        // Then
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Memory Management Tests

    func testCleanupClearsState() {
        // Given
        stack.dismissalAction[0] = { }
        let item = NavigationStackItem(
            presentationType: MockPresentationType(),
            content: .view(AnyView(Text("Test"))),
            keyPath: 123,
            input: nil
        )
        stack.push(item)

        // When
        stack.cleanup()

        // Then
        XCTAssertTrue(stack.value.isEmpty)
        XCTAssertTrue(stack.dismissalAction.isEmpty)
    }

    // MARK: - NavigationRoot Tests

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
        root.item = item2

        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
}

// MARK: - Test Helpers

@MainActor
final class TestStackCoordinator: NavigationCoordinatable {
    let stack = Stinsen.NavigationStack<TestStackCoordinator>(initial: \.main)

    @Root var main = makeMain

    func makeMain() -> some View {
        Text("Main")
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
}
