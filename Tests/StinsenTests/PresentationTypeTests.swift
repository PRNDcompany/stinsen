//
//  PresentationTypeTests.swift
//  StinsenTests
//
//  TDD tests for PresentationType hierarchy simplification (Phase 6)
//

import XCTest
@testable import Stinsen
import SwiftUI
import UIKit

@MainActor
final class PresentationTypeTests: XCTestCase {

    // MARK: - 6.1: PresentationType has UIKit methods

    /// PresentationType conformer should be able to implement all UIKit methods
    /// without needing UIKitPresentationType
    func testPresentationTypeHasUIKitMethods() {
        let pt: PresentationType = TestDirectPresentationType()

        // Should compile and work — all methods directly on PresentationType
        let vc = pt.makeViewController(content: Text("Hello"))
        XCTAssertNotNil(vc)

        // presented/dismissed should be callable
        pt.presented(
            parent: UIViewController(),
            content: vc,
            onAppeared: {},
            onDismissed: {}
        )
        pt.dismissed(viewController: vc)
    }

    // MARK: - 6.3: AnyPresentationType direct forwarding (no runtime cast)

    /// AnyPresentationType should forward UIKit methods directly
    /// without needing `as? UIKitPresentationType` runtime cast
    func testAnyPresentationTypeDirectForwarding() {
        let inner = TestDirectPresentationType()
        let any = AnyPresentationType(inner)

        let vc = any.makeViewController(content: Text("Test"))
        XCTAssertNotNil(vc)
        XCTAssertTrue(inner.makeViewControllerCalled)
    }

    // MARK: - 6.4: AnyPresentationType convenience init

    /// AnyPresentationType should be creatable with closures directly
    func testAnyPresentationTypeConvenienceInit() {
        let anyPT = AnyPresentationType(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { parent, vc in
                parent.present(vc, animated: false)
            }
        )

        let vc = anyPT.makeViewController(content: Text("Convenience"))
        XCTAssertTrue(vc is UIHostingController<AnyView>)
    }

    // MARK: - 6.5: Static factories

    func testStaticFactoryPush() {
        let push = AnyPresentationType.push
        let vc = push.makeViewController(content: Text("Push"))
        XCTAssertNotNil(vc)
    }

    func testStaticFactoryModal() {
        let modal = AnyPresentationType.modal
        let vc = modal.makeViewController(content: Text("Modal"))
        XCTAssertNotNil(vc)
    }

    func testStaticFactoryFullScreen() {
        let fullScreen = AnyPresentationType.fullScreen
        let vc = fullScreen.makeViewController(content: Text("FullScreen"))
        XCTAssertNotNil(vc)
    }

    // MARK: - 6.6: ViewControllerPresented uses PresentationType

    func testViewControllerPresentedUsesPresentationType() {
        let pt = TestDirectPresentationType()
        let vc = UIViewController()

        // Should accept PresentationType directly, not just UIKitPresentationType
        let presented = ViewControllerPresented(
            viewController: vc,
            presentationType: pt
        )

        XCTAssertNotNil(presented.viewController)
        presented.dismiss()
        XCTAssertTrue(pt.dismissedCalled)
    }
}

// MARK: - Test Helpers

/// A PresentationType conformer that does NOT use UIKitPresentationType
@MainActor
private class TestDirectPresentationType: PresentationType {
    var makeViewControllerCalled = false
    var presentedCalled = false
    var dismissedCalled = false

    func makePresented<T: NavigationCoordinatable>(
        content: StackItemContent,
        nextId: Int,
        coordinator: T
    ) -> ViewControllerPresented? {
        return nil
    }

    func makeViewController<Content: View>(content: Content) -> UIViewController {
        makeViewControllerCalled = true
        return UIHostingController(rootView: content)
    }

    func presented(
        parent: UIViewController,
        content: UIViewController,
        onAppeared: @escaping () -> Void,
        onDismissed: @escaping () -> Void
    ) {
        presentedCalled = true
    }

    func dismissed(viewController: UIViewController) {
        dismissedCalled = true
    }
}
