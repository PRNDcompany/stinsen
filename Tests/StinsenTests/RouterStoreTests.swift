//
//  RouterStoreTests.swift
//  StinsenTests
//
//  Unit tests for RouterStore functionality
//

import XCTest
@testable import Stinsen
import SwiftUI

final class RouterStoreTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear any existing routers in the singleton
        // Note: This is why singleton pattern makes testing harder
        clearRouterStore()
    }
    
    override func tearDown() {
        clearRouterStore()
        super.tearDown()
    }
    
    // Helper to clear the router store
    private func clearRouterStore() {
        // Store and retrieve a dummy router to trigger cleanup
        let dummy = TestRouter()
        RouterStore.shared.store(router: dummy)
        let _: TestRouter? = RouterStore.shared.retrieve()
    }
    
    // MARK: - Storage and Retrieval Tests
    
    func testStoreAndRetrieveRouter() {
        // Given
        let router = TestRouter()
        router.testValue = "Test"
        
        // When
        RouterStore.shared.store(router: router)
        let retrieved: TestRouter? = RouterStore.shared.retrieve()
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.testValue, "Test")
    }
    
    func testRetrieveReturnsNilWhenNoRouterStored() {
        // When
        let retrieved: TestRouter? = RouterStore.shared.retrieve()
        
        // Then
        XCTAssertNil(retrieved)
    }
    
    func testStoreMultipleRoutersOfDifferentTypes() {
        // Given
        let testRouter = TestRouter()
        let anotherRouter = AnotherTestRouter()
        
        // When
        RouterStore.shared.store(router: testRouter)
        RouterStore.shared.store(router: anotherRouter)
        
        let retrievedTest: TestRouter? = RouterStore.shared.retrieve()
        let retrievedAnother: AnotherTestRouter? = RouterStore.shared.retrieve()
        
        // Then
        XCTAssertNotNil(retrievedTest)
        XCTAssertNotNil(retrievedAnother)
    }
    
    func testMostRecentRouterIsRetrievedFirst() {
        // Given
        let firstRouter = TestRouter()
        firstRouter.testValue = "First"
        let secondRouter = TestRouter()
        secondRouter.testValue = "Second"
        
        // When
        RouterStore.shared.store(router: firstRouter)
        RouterStore.shared.store(router: secondRouter)
        
        let retrieved: TestRouter? = RouterStore.shared.retrieve()
        
        // Then
        XCTAssertEqual(retrieved?.testValue, "Second")
    }
    
    // MARK: - Weak Reference Tests
    
    func testWeakReferenceIsCleanedUp() {
        // Given
        weak var weakRouter: TestRouter?
        
        autoreleasepool {
            let router = TestRouter()
            weakRouter = router
            RouterStore.shared.store(router: router)
            
            // Verify it's stored
            let retrieved: TestRouter? = RouterStore.shared.retrieve()
            XCTAssertNotNil(retrieved)
        }
        
        // When - router should be deallocated
        XCTAssertNil(weakRouter)
        
        // Then - should not be retrievable
        let retrieved: TestRouter? = RouterStore.shared.retrieve()
        XCTAssertNil(retrieved)
    }
    
    func testWeakReferencesCleanedOnStore() {
        // Given - store 5 routers, keep strong references
        var routers: [TestRouter] = []
        for i in 0..<5 {
            let router = TestRouter()
            router.testValue = "Router \(i)"
            routers.append(router)
            RouterStore.shared.store(router: router)
        }

        // Verify most recent is retrievable
        let before: TestRouter? = RouterStore.shared.retrieve()
        XCTAssertEqual(before?.testValue, "Router 4")

        // When - release all strong references, causing deallocation
        routers.removeAll()

        // Force cleanup by storing a new router (store() filters nil weak refs)
        let newRouter = TestRouter()
        newRouter.testValue = "New"
        RouterStore.shared.store(router: newRouter)

        // Then - only the new router should be retrievable
        let after: TestRouter? = RouterStore.shared.retrieve()
        XCTAssertEqual(after?.testValue, "New")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccessIsSafe() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100
        
        let queue1 = DispatchQueue(label: "test.queue1", attributes: .concurrent)
        let queue2 = DispatchQueue(label: "test.queue2", attributes: .concurrent)
        
        // When - perform concurrent operations
        for i in 0..<50 {
            queue1.async {
                let router = TestRouter()
                router.testValue = "Queue1-\(i)"
                RouterStore.shared.store(router: router)
                expectation.fulfill()
            }
            
            queue2.async {
                let _: TestRouter? = RouterStore.shared.retrieve()
                expectation.fulfill()
            }
        }
        
        // Then - should complete without crashes
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - RouterObject Property Wrapper Tests
    
    func testRouterObjectPropertyWrapper() {
        // Given
        let router = TestRouter()
        RouterStore.shared.store(router: router)
        
        // When
        var container = RouterObjectContainer()

        // Then
        XCTAssertNotNil(container.router)
    }
    
    func testRouterObjectCachesReference() {
        // Given
        let router = TestRouter()
        router.testValue = "Initial"
        RouterStore.shared.store(router: router)

        var container = RouterObjectContainer()
        let firstAccess = container.router
        XCTAssertEqual(firstAccess?.testValue, "Initial")

        // When - store a different router
        let newRouter = TestRouter()
        newRouter.testValue = "New"
        RouterStore.shared.store(router: newRouter)

        // Then - should still return the cached (first) reference, not the new one
        let secondAccess = container.router
        XCTAssertEqual(secondAccess?.testValue, "Initial",
                       "RouterObject should cache the first retrieved reference")
    }
}

// MARK: - Test Helpers

class TestRouter: Routable {
    var testValue: String = ""
}

class AnotherTestRouter: Routable {
    var anotherValue: Int = 0
}

struct RouterObjectContainer {
    @RouterObject var router: TestRouter?
}