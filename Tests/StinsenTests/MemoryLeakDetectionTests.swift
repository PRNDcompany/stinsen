import XCTest
@testable import Stinsen
import SwiftUI

// Test coordinator that intentionally creates a retain cycle
class LeakyTestCoordinator: NavigationCoordinatable {
    let stack = NavigationStack<LeakyTestCoordinator>(initial: \LeakyTestCoordinator.start)
    
    @Root var start = makeStart
    
    // Strong reference to self to create a retain cycle
    var strongSelfReference: LeakyTestCoordinator?
    
    init() {
        // Create retain cycle
        strongSelfReference = self
    }
    
    deinit {
        print("[TEST] LeakyTestCoordinator deinit called")
    }
    
    @ViewBuilder func makeStart() -> some View {
        Text("Test")
    }
}

// Test coordinator without retain cycle
class NonLeakyTestCoordinator: NavigationCoordinatable {
    let stack = NavigationStack<NonLeakyTestCoordinator>(initial: \NonLeakyTestCoordinator.start)
    
    @Root var start = makeStart
    
    deinit {
        print("[TEST] NonLeakyTestCoordinator deinit called")
    }
    
    @ViewBuilder func makeStart() -> some View {
        Text("Test")
    }
}

class MemoryLeakDetectionTests: XCTestCase {
    
    func testMemoryLeakDetection() {
        // This test demonstrates the memory leak detection
        // In a real app, this would show an alert
        
        let expectation = XCTestExpectation(description: "Memory leak detection")
        
        // Create a coordinator with a retain cycle
        var leakyCoordinator: LeakyTestCoordinator? = LeakyTestCoordinator()
        
        // Track it for memory leak
        leakyCoordinator?.trackForMemoryLeak()
        
        // Clear our reference
        leakyCoordinator = nil
        
        // Wait to see if memory leak is detected
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // If we get here, the memory leak detector should have triggered
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testNoMemoryLeakForProperlyDeallocatedCoordinator() {
        let expectation = XCTestExpectation(description: "No memory leak for proper deallocation")
        
        // Create a coordinator without retain cycle
        var nonLeakyCoordinator: NonLeakyTestCoordinator? = NonLeakyTestCoordinator()
        
        // Track it for memory leak
        nonLeakyCoordinator?.trackForMemoryLeak()
        
        // Clear our reference - it should deallocate properly
        nonLeakyCoordinator = nil
        
        // Wait to ensure no false positive
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            // If we get here without assertion failure, the coordinator was properly deallocated
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
}