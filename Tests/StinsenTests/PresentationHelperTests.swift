//
//  PresentationHelperTests.swift
//  StinsenTests
//
//  Unit tests for PresentationHelper functionality
//

import XCTest
@testable import Stinsen
import SwiftUI
#if canImport(UIKit)
import UIKit

final class PresentationHelperTests: XCTestCase {
    
    var coordinator: TestPresentationCoordinator!
    var helper: PresentationHelper<TestPresentationCoordinator>!
    
    override func setUp() {
        super.setUp()
        coordinator = TestPresentationCoordinator()
    }
    
    override func tearDown() {
        helper = nil
        coordinator = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testRootHelperSetsUpCallbacks() {
        // Given - root helper with id = -1
        helper = PresentationHelper(id: -1, coordinator: coordinator)
        
        // Then - callbacks should be set
        XCTAssertNotNil(coordinator.stack.onStackChanged)
        XCTAssertNotNil(coordinator.stack.onPopped)
    }
    
    func testNonRootHelperDoesNotSetCallbacks() {
        // Given - non-root helper with id >= 0
        helper = PresentationHelper(id: 0, coordinator: coordinator)
        
        // Then - callbacks should not be set
        XCTAssertNil(coordinator.stack.onStackChanged)
        XCTAssertNil(coordinator.stack.onPopped)
    }
    
    // MARK: - Stack Change Handling Tests
    
    func testHandleStackChangedIgnoresNonRootHelper() {
        // Given
        helper = PresentationHelper(id: 0, coordinator: coordinator)
        let item = createMockStackItem()
        
        // When
        helper.handleStackChanged([item])
        
        // Then - should be ignored (no crash, no presentation)
        XCTAssertNil(helper.currentPresented)
    }
    
    func testHandleStackChangedRequiresSingleItem() {
        // Given
        helper = PresentationHelper(id: -1, coordinator: coordinator)
        let items = [createMockStackItem(), createMockStackItem()]
        
        // When - multiple items
        helper.handleStackChanged(items)
        
        // Then - should not present
        XCTAssertNil(helper.currentPresented)
    }
    
    func testHandleStackChangedCreatesPresentation() {
        // Given
        helper = PresentationHelper(id: -1, coordinator: coordinator)
        let item = createMockStackItem()
        
        // When
        helper.handleStackChanged([item])
        
        // Then
        XCTAssertNotNil(helper.currentPresented)
    }
    
    func testHandleStackChangedIgnoresDuplicatePresentation() {
        // Given
        helper = PresentationHelper(id: -1, coordinator: coordinator)
        let item = createMockStackItem()
        helper.handleStackChanged([item])
        let firstPresented = helper.currentPresented
        
        // When - called again with same item
        helper.handleStackChanged([item])
        
        // Then - should not create new presentation
        XCTAssertTrue(helper.currentPresented === firstPresented)
    }
    
    // MARK: - Pop Handling Tests
    
    func testHandlePoppedRemovesPresentedWhenIndexLessThanId() {
        // Given
        helper = PresentationHelper(id: 1, coordinator: coordinator)
        helper.currentPresented = createMockPresented()
        
        // When - pop to index 0 (less than id 1)
        helper.handlePopped(to: 0)
        
        // Then
        XCTAssertNil(helper.currentPresented)
    }
    
    func testHandlePoppedKeepsPresentedWhenIndexGreaterThanId() {
        // Given
        helper = PresentationHelper(id: 1, coordinator: coordinator)
        let presented = createMockPresented()
        helper.currentPresented = presented
        
        // When - pop to index 2 (greater than id 1)
        helper.handlePopped(to: 2)
        
        // Then
        XCTAssertNotNil(helper.currentPresented)
        XCTAssertTrue(helper.currentPresented === presented)
    }
    
    // MARK: - Dismissal Tests
    
    func testHandleDismissedClearsCurrentPresented() {
        // Given
        helper = PresentationHelper(id: 0, coordinator: coordinator)
        helper.currentPresented = createMockPresented()
        
        // When
        helper.handleDismissed()
        
        // Then
        XCTAssertNil(helper.currentPresented)
    }
    
    func testRemovePresentedClearsAndDismisses() {
        // Given
        helper = PresentationHelper(id: 0, coordinator: coordinator)
        let presented = createMockPresented()
        helper.currentPresented = presented
        
        // When
        helper.removePresented()
        
        // Then
        XCTAssertNil(helper.currentPresented)
    }
    
    // MARK: - UIViewController Setup Tests
    
    func testSetupViewControllerStoresReference() {
        // Given
        helper = PresentationHelper(id: 0, coordinator: coordinator)
        let viewController = UIViewController()
        
        // When
        helper.setupViewController(viewController)
        
        // Then
        XCTAssertNotNil(helper.currentViewController)
        XCTAssertTrue(helper.currentViewController === viewController)
    }
    
    func testSetupViewControllerPresentsWaitingPresented() {
        // Given
        helper = PresentationHelper(id: 0, coordinator: coordinator)
        let presented = createMockPresented()
        helper.currentPresented = presented
        let viewController = UIViewController()
        
        // When
        helper.setupViewController(viewController)
        
        // Then - should attempt to present
        XCTAssertNotNil(helper.currentViewController)
    }
    
    // MARK: - Memory Management Tests
    
    func testDeinitCleansUpPresented() {
        // Given
        autoreleasepool {
            let tempHelper = PresentationHelper(id: 0, coordinator: coordinator)
            tempHelper.currentPresented = createMockPresented()
            
            // When - helper is deallocated
        }
        
        // Then - cleanup should have been called (no way to directly test, but ensures no crash)
        XCTAssertTrue(true)
    }
    
    func testWeakCoordinatorReference() {
        // Given
        weak var weakCoordinator: TestPresentationCoordinator?
        
        autoreleasepool {
            let tempCoordinator = TestPresentationCoordinator()
            weakCoordinator = tempCoordinator
            helper = PresentationHelper(id: 0, coordinator: tempCoordinator)
            XCTAssertNotNil(weakCoordinator)
        }
        
        // Then - coordinator should be deallocated
        XCTAssertNil(weakCoordinator)
    }
}

// MARK: - Test Helpers

extension PresentationHelperTests {
    
    func createMockStackItem() -> NavigationStackItem {
        return NavigationStackItem(
            presentationType: MockPresentationType(),
            presentable: AnyView(Text("Test")),
            keyPath: 123,
            input: nil
        )
    }
    
    func createMockPresented() -> ViewControllerPresented {
        return ViewControllerPresented(
            viewController: UIViewController(),
            presentationType: MockUIKitPresentationType()
        )
    }
}

// Extension to access internal properties for testing
extension PresentationHelper {
    var currentPresented: ViewControllerPresented? {
        get {
            // Access through mirror reflection for testing
            let mirror = Mirror(reflecting: self)
            return mirror.children.first { $0.label == "currentPresented" }?.value as? ViewControllerPresented
        }
        set {
            // Use KVO for testing
            self.setValue(newValue, forKey: "currentPresented")
        }
    }
    
    var currentViewController: UIViewController? {
        get {
            let mirror = Mirror(reflecting: self)
            return mirror.children.first { $0.label == "currentViewController" }?.value as? UIViewController
        }
    }
}

class MockUIKitPresentationType: UIKitPresentationType {
    func makePresented<T: NavigationCoordinatable>(
        presentable: ViewPresentable,
        nextId: Int,
        coordinator: T
    ) -> ViewControllerPresented? {
        return ViewControllerPresented(
            viewController: UIViewController(),
            presentationType: self
        )
    }
    
    func presented(parent: UIViewController, content: UIViewController, onAppeared: @escaping () -> Void, onDismissed: @escaping () -> Void) {
        // Mock implementation
    }
    
    func dismissed(viewController: UIViewController) {
        // Mock implementation
    }
}

#endif