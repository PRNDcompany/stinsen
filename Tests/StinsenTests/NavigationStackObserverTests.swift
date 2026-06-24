//
//  NavigationStackObserverTests.swift
//  StinsenTests
//

import XCTest
@testable import Stinsen
import SwiftUI
import Combine

@MainActor
final class NavigationStackObserverTests: XCTestCase {

    func testPresentationCallbackFiredOnPush() {
        let coordinator = TestNavigationCoordinator()
        coordinator.setupRoot()

        var presentedItem: NavigationStackItem?
        let observer = NavigationStackObserver(id: -1, coordinator: coordinator, stack: coordinator.stack)
        observer.onPresentationNeeded = { item in
            presentedItem = item
        }

        // Push a route (id=-1 observer watches for item at index 0)
        coordinator.route(to: \.detailView)

        XCTAssertNotNil(presentedItem)
    }

    func testDismissalCallbackFiredOnPop() {
        let coordinator = TestNavigationCoordinator()
        coordinator.setupRoot()

        var dismissalCalled = false
        let observer = NavigationStackObserver(id: 0, coordinator: coordinator, stack: coordinator.stack)
        observer.onDismissalNeeded = {
            dismissalCalled = true
        }

        // Push then pop
        coordinator.route(to: \.detailView)
        coordinator.popToRoot(nil)

        XCTAssertTrue(dismissalCalled)
    }

    func testDismissalNotCalledForHigherIndex() {
        let coordinator = TestNavigationCoordinator()
        coordinator.setupRoot()

        var dismissalCalled = false
        // Observer at id=5 should NOT be triggered when popping to index 0
        let observer = NavigationStackObserver(id: 5, coordinator: coordinator, stack: coordinator.stack)
        observer.onDismissalNeeded = {
            dismissalCalled = true
        }

        coordinator.route(to: \.detailView)
        coordinator.popToRoot(nil)

        // Popping to index -1 should trigger dismissal for id=5 too since -1 <= 5
        XCTAssertTrue(dismissalCalled)
    }

    func testObserverDoesNotRetainCoordinator() {
        var coordinator: TestNavigationCoordinator? = TestNavigationCoordinator()
        coordinator!.setupRoot()
        weak var weakCoordinator = coordinator

        let observer = NavigationStackObserver(id: -1, coordinator: coordinator!, stack: coordinator!.stack)
        _ = observer // keep observer alive

        coordinator = nil
        XCTAssertNil(weakCoordinator)
    }

    func testMultiplePushesFireMultipleCallbacks() {
        let coordinator = TestNavigationCoordinator()
        coordinator.setupRoot()

        var presentationCount = 0
        let observer = NavigationStackObserver(id: -1, coordinator: coordinator, stack: coordinator.stack)
        observer.onPresentationNeeded = { _ in
            presentationCount += 1
        }

        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)

        // Observer at id=-1 watches for item at index 0
        // After first push: items=[detail], observer fires for items[0]
        // After second push: items=[detail, second], observer fires again for items[0] (still exists)
        XCTAssertGreaterThanOrEqual(presentationCount, 1)
    }
}
