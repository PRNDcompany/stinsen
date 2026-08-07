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

    /// Presenting plants nothing on the content view controller.
    ///
    /// `onDismissed` used to be driven by an associated object whose `deinit` fired it —
    /// which meant every presented screen carried a hidden passenger, and the callback
    /// arrived whenever ARC felt like it, in no order, and not at all if anything still
    /// held the view controller. Disappearance is observed by `ScreenProbe` and
    /// re-derived by `reconcile()` now, so nothing needs planting.
    ///
    /// This matters beyond tidiness: once an app can hand its *own* view controller in as
    /// a screen, attaching hidden state to it is attaching it to someone else's object.
    func testPresentingDoesNotAttachAnythingToTheContentViewController() {
        let presentation = UIKitPresentation(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { _, _ in }
        )
        let content = presentation.makeViewController(content: Text("Test"))

        let childrenBefore = content.children.count
        var onDismissedCalled = false

        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: {},
            onDismissed: { onDismissedCalled = true }
        )

        XCTAssertEqual(content.children.count, childrenBefore,
                       "presenting must not add anything to the content view controller")

        // The callback is never invoked by a built-in presentation. Released here so the
        // assertion is about the contract rather than about timing.
        let settled = XCTestExpectation(description: "settle")
        settled.isInverted = true
        wait(for: [settled], timeout: 0.3)
        XCTAssertFalse(onDismissedCalled,
                       "disappearance is reported by the probe, not by this callback")
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
    let stack = CoordinatorStack<TestReentryCoordinator>(initial: \.main)

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
