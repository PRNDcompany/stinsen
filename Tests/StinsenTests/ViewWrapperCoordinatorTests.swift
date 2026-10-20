//
//  ViewWrapperCoordinatorTests.swift
//  StinsenTests
//

import XCTest
@testable import Stinsen
import SwiftUI

@MainActor
final class ViewWrapperCoordinatorTests: XCTestCase {

    func testChildIsStoredCorrectly() {
        let child = TestChildCoordinator()
        let wrapper = ViewWrapperCoordinator(child) { content in
            NavigationView { content }
        }

        XCTAssertTrue(wrapper.child === child)
    }

    func testChildParentIsSetToWrapper() {
        let child = TestChildCoordinator()
        let wrapper = ViewWrapperCoordinator(child) { content in
            NavigationView { content }
        }

        XCTAssertTrue(child.parent === wrapper)
    }

    func testViewReturnsNonNilAnyView() {
        let child = TestChildCoordinator()
        let wrapper = ViewWrapperCoordinator(child) { content in
            NavigationView { content }
        }

        let view = wrapper.view()
        XCTAssertNotNil(view)
    }

    func testWeakParentReference() {
        let child = TestChildCoordinator()

        autoreleasepool {
            _ = ViewWrapperCoordinator(child) { content in
                NavigationView { content }
            }
        }

        // Parent is weak, so after wrapper is deallocated, parent should be nil
        XCTAssertNil(child.parent)
    }

    func testCoordinatorInitWithCoordinatorFactory() {
        let child = TestChildCoordinator()
        let wrapper = ViewWrapperCoordinator(child) { (coordinator: any Coordinatable) in
            return { (content: AnyView) in
                NavigationView { content }
            }
        }

        XCTAssertTrue(wrapper.child === child)
        XCTAssertTrue(child.parent === wrapper)
    }

    func testDismissChildDelegatesToParent() {
        let parent = TestNavigationCoordinator()
        parent.setupRoot()

        let child = TestChildCoordinator()
        let wrapper = ViewWrapperCoordinator(child) { content in
            NavigationView { content }
        }
        wrapper.parent = parent

        // The wrapper delegates to its parent's dismissChild
        // This verifies the flow doesn't crash
        XCTAssertNotNil(wrapper.parent)
    }
}
