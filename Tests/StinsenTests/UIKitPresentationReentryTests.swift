//
//  UIKitPresentationReentryTests.swift
//  StinsenTests
//
//  Unit tests for UIKitPresentation re-entry scenarios
//

import XCTest
@testable import Stinsen
#if canImport(UIKit)
import UIKit
import SwiftUI

@MainActor
final class UIKitPresentationReentryTests: XCTestCase {

    var coordinator: TestReentryCoordinator!
    var parentViewController: UIViewController!

    override func setUp() {
        super.setUp()
        coordinator = TestReentryCoordinator()
        parentViewController = UIViewController()
    }

    override func tearDown() {
        coordinator = nil
        parentViewController = nil
        super.tearDown()
    }

    // MARK: - Re-entry Tests

    func testPushPopPushScenario() {
        // Given
        let expectation = XCTestExpectation(description: "Re-entry works")

        // First push: A → B
        coordinator.route(to: \.detail)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        // Pop: B → A
        coordinator.popLast()
        XCTAssertEqual(coordinator.stack.value.count, 0)

        // Second push (re-entry): A → B
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.coordinator.route(to: \.detail)
            XCTAssertEqual(self.coordinator.stack.value.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - UIKitPresentation Callback Tests

    func testPresentedCallsOnAppearedAsync() {
        // Given
        let presentation = UIKitPresentation(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { _, _ in }
        )
        // Use makeViewController to get the correct ViewController type (UIHostingController<AnyView>)
        let content = presentation.makeViewController(content: Text("Test"))
        let expectation = XCTestExpectation(description: "onAppeared called")

        // When
        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: {
                expectation.fulfill()
            },
            onDismissed: {}
        )

        // Then
        wait(for: [expectation], timeout: 0.5)
    }

    func testOnDismissedNotCalledDuringPresent() {
        // Given
        let presentation = UIKitPresentation(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { _, _ in }
        )
        // Use makeViewController to get the correct ViewController type (UIHostingController<AnyView>)
        let content = presentation.makeViewController(content: Text("Test"))
        var onDismissedCalled = false

        // When
        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: {},
            onDismissed: { onDismissedCalled = true }
        )

        // Wait to ensure onDismissed is not called
        let expectation = XCTestExpectation(description: "Wait for potential onDismissed")
        expectation.isInverted = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if onDismissedCalled {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(onDismissedCalled, "onDismissed should not be called during present")
    }

    func testMakeViewControllerCreatesCorrectType() {
        // Given
        let presentation = UIKitPresentation(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { _, _ in }
        )

        // When
        let vc = presentation.makeViewController(content: Text("Test"))

        // Then
        XCTAssertTrue(vc is UIHostingController<AnyView>)
    }
}

// MARK: - Test Helpers

@MainActor
final class TestReentryCoordinator: NavigationCoordinatable {
    let stack = Stinsen.NavigationStack<TestReentryCoordinator>(initial: \.main)

    @Root var main = makeMain
    @Route(.push) var detail = makeDetail
    @Route(.modal) var modal = makeModal

    func makeMain() -> some View {
        Text("Main")
    }

    func makeDetail() -> some View {
        Text("Detail")
    }

    func makeModal() -> some View {
        Text("Modal")
    }
}

#endif
