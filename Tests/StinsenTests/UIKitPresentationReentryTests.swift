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

final class UIKitPresentationReentryTests: XCTestCase {
    
    var coordinator: TestPresentationCoordinator!
    var parentViewController: UIViewController!
    
    override func setUp() {
        super.setUp()
        coordinator = TestPresentationCoordinator()
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
        let firstChild = coordinator.route(to: \.detail)
        XCTAssertEqual(coordinator.stack.value.count, 1)
        
        // Pop: B → A
        coordinator.popLast()
        XCTAssertEqual(coordinator.stack.value.count, 0)
        
        // Second push (re-entry): A → B
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let secondChild = self.coordinator.route(to: \.detail)
            XCTAssertEqual(self.coordinator.stack.value.count, 1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testModalPresentDismissReentry() {
        // Given
        let presentation = TestModalPresentation()
        let content = UIViewController()
        var onAppearedCount = 0
        var onDismissedCount = 0
        
        // First present
        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: { onAppearedCount += 1 },
            onDissmissed: { onDismissedCount += 1 }
        )
        
        // Wait for async onAppeared
        let firstExpectation = XCTestExpectation(description: "First present")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(onAppearedCount, 1)
            firstExpectation.fulfill()
        }
        wait(for: [firstExpectation], timeout: 0.5)
        
        // Dismiss
        presentation.dismissed(viewController: content)
        
        // Re-entry: Second present
        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: { onAppearedCount += 1 },
            onDissmissed: { onDismissedCount += 1 }
        )
        
        // Wait for second async onAppeared
        let secondExpectation = XCTestExpectation(description: "Second present")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(onAppearedCount, 2, "onAppeared should be called twice")
            secondExpectation.fulfill()
        }
        wait(for: [secondExpectation], timeout: 0.5)
    }
    
    // MARK: - LifeCicleObject Tests
    
    func testLifeCicleObjectClearedOnDismiss() {
        // Given
        let presentation = TestModalPresentation()
        let content = UIViewController()
        
        // Present
        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: {},
            onDissmissed: {}
        )
        
        // Verify lifeCicleObject is set
        XCTAssertNotNil(content.lifeCicleObject)
        
        // Dismiss
        presentation.dismissed(viewController: content)
        
        // Verify lifeCicleObject is cleared
        XCTAssertNil(content.lifeCicleObject, "lifeCicleObject should be cleared on dismiss")
    }
    
    func testLifeCicleObjectReplacedOnReentry() {
        // Given
        let presentation = TestModalPresentation()
        let content = UIViewController()
        
        // First present
        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: {},
            onDissmissed: {}
        )
        
        let firstLifeCicleObject = content.lifeCicleObject
        XCTAssertNotNil(firstLifeCicleObject)
        
        // Second present (re-entry without dismiss)
        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: {},
            onDissmissed: {}
        )
        
        let secondLifeCicleObject = content.lifeCicleObject
        XCTAssertNotNil(secondLifeCicleObject)
        XCTAssertTrue(firstLifeCicleObject !== secondLifeCicleObject, "LifeCicleObject should be replaced on re-entry")
    }
    
    // MARK: - Callback Timing Tests
    
    func testOnAppearedCalledAfterPresent() {
        // Given
        let presentation = TestModalPresentation()
        let content = UIViewController()
        let expectation = XCTestExpectation(description: "onAppeared called")
        var presentHandlerCalled = false
        var onAppearedCalledAfterPresent = false
        
        // Custom presentation to track timing
        let customPresentation = UIKitPresentation(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { _, _ in 
                presentHandlerCalled = true
            }
        )
        
        // Present
        customPresentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: {
                onAppearedCalledAfterPresent = presentHandlerCalled
                expectation.fulfill()
            },
            onDissmissed: {}
        )
        
        wait(for: [expectation], timeout: 0.5)
        XCTAssertTrue(onAppearedCalledAfterPresent, "onAppeared should be called after presentHandler")
    }
    
    func testOnDismissedNotCalledWithOnAppeared() {
        // Given
        let presentation = TestModalPresentation()
        let content = UIViewController()
        var onDismissedCalled = false
        
        // Present
        presentation.presented(
            parent: parentViewController,
            content: content,
            onAppeared: {
                // This should be called
            },
            onDissmissed: {
                onDismissedCalled = true
            }
        )
        
        // Wait to ensure onDissmissed is not called
        let expectation = XCTestExpectation(description: "Wait for potential onDissmissed")
        expectation.isInverted = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if onDismissedCalled {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 0.5)
        XCTAssertFalse(onDismissedCalled, "onDissmissed should not be called during present")
    }
}

// MARK: - Test Helpers

final class TestPresentationCoordinator: NavigationCoordinatable {
    let stack = NavigationStack<TestPresentationCoordinator>(initial: \.main)
    weak var parent: ChildDismissable?
    
    @Route(.push) var main = makeMain
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
    
    typealias CustomizeViewType = AnyView
    typealias RouterStoreType = TestPresentationCoordinator
}

class TestModalPresentation: UIKitPresentation<UIViewController> {
    init() {
        super.init(
            make: { content, _ in
                UIHostingController(rootView: content)
            },
            present: { parent, viewController in
                // Simulate modal presentation
                parent.present(viewController, animated: false)
            },
            dismiss: { viewController in
                viewController.dismiss(animated: false)
            }
        )
    }
}

// Extension to access private lifeCicleObject for testing
extension UIViewController {
    var lifeCicleObject: LifeCicleObject? {
        get { MapTables.lifeCicle.value(forKey: self) as? LifeCicleObject }
        set { MapTables.lifeCicle.setValue(newValue, forKey: self) }
    }
}

// Access to private types for testing
private enum MapTables {
    static let lifeCicle = WeakMapTable<UIViewController, Any>()
}

private final class LifeCicleObject {
    var onDeinit: (() -> Void)?
    deinit {
        onDeinit?()
    }
}

#endif