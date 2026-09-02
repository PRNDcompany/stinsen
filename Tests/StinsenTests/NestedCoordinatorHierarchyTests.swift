//
//  NestedCoordinatorHierarchyTests.swift
//  StinsenTests
//
//  What the UIKit hierarchy actually looks like when a SwiftUI coordinator shows another
//  SwiftUI coordinator. Everything else in the suite binds a coordinator to a bare anchor
//  through `HostFixture`; this one goes in the front door — `viewController()`, a real
//  window, a real render — because the question is about what the front door builds.
//

import XCTest
@testable import Stinsen
import SwiftUI
import UIKit

@MainActor
final class NestedCoordinatorHierarchyTests: XCTestCase {

    private var window: UIWindow!

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func pump(_ duration: TimeInterval = 0.6) {
        RunLoop.current.run(until: Date().addingTimeInterval(duration))
    }

    /// Reports the chain as types, so a failure says what was built rather than that a
    /// number was wrong.
    private func describe(_ navigation: UINavigationController) -> String {
        navigation.viewControllers.map { String(describing: type(of: $0)) }.joined(separator: " → ")
    }

    func testSwiftUIParentShowingSwiftUIChild() {
        let parent = OuterCoordinator()
        let navigation = UINavigationController(rootViewController: parent.viewController())
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        pump()

        XCTAssertNotNil(parent.host.base, "the parent's anchor comes from its own render")

        let child = parent.route(.push, to: InnerCoordinator())
        pump()

        let childCoordinator = child as InnerCoordinator
        XCTAssertNotNil(childCoordinator.host.base,
            "the child gets an anchor of its own from its own render — hierarchy: \(describe(navigation))")

        childCoordinator.route(.push, to: Text("grandchild"))
        pump()

        print("STINSEN-HIERARCHY: \(describe(navigation))")
        print("STINSEN-PARENT-BASE: \(String(describing: parent.host.base.map { type(of: $0) }))")
        print("STINSEN-CHILD-BASE: \(String(describing: childCoordinator.host.base.map { type(of: $0) }))")
        print("STINSEN-SAME-NAV: \(parent.host.base?.navigationController === childCoordinator.host.base?.navigationController)")
        print("STINSEN-PARENT-RECORDS: \(parent.host.records.count) CHILD-RECORDS: \(childCoordinator.host.records.count)")

        XCTAssertEqual(navigation.viewControllers.count, 3,
            "parent root, child root, grandchild — all in one UIKit stack: \(describe(navigation))")
    }
}

// MARK: - Test Helpers

@MainActor
private final class OuterCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<OuterCoordinator>(initial: \.start)
    @Root var start = makeStart
    @ViewBuilder func makeStart() -> some View { Text("outer") }
}

@MainActor
private final class InnerCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<InnerCoordinator>(initial: \.start)
    @Root var start = makeStart
    @ViewBuilder func makeStart() -> some View { Text("inner") }
}
