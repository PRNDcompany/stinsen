//
//  NavigationReentryUITests.swift
//  StinsenUITests
//
//  UI tests for navigation re-entry scenarios
//

import XCTest

final class NavigationReentryUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - Navigation Re-entry Tests
    
    func testPushPopPushReentry() {
        // Given - Main screen is visible
        let mainTitle = app.navigationBars["Main"]
        XCTAssertTrue(mainTitle.exists)
        
        // When - Navigate to detail
        let detailButton = app.buttons["ShowDetail"]
        XCTAssertTrue(detailButton.exists)
        detailButton.tap()
        
        // Then - Detail screen is visible
        let detailTitle = app.navigationBars["Detail"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2))
        
        // When - Go back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists)
        backButton.tap()
        
        // Then - Main screen is visible again
        XCTAssertTrue(mainTitle.waitForExistence(timeout: 2))
        
        // When - Navigate to detail again (re-entry)
        XCTAssertTrue(detailButton.exists)
        detailButton.tap()
        
        // Then - Detail screen is visible again
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2), "Re-entry navigation should work")
    }
    
    func testSwipeBackAndReentry() {
        // Given - Navigate to detail
        let detailButton = app.buttons["ShowDetail"]
        detailButton.tap()
        
        let detailTitle = app.navigationBars["Detail"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2))
        
        // When - Swipe back
        app.swipeRight()
        
        // Then - Main screen is visible
        let mainTitle = app.navigationBars["Main"]
        XCTAssertTrue(mainTitle.waitForExistence(timeout: 2))
        
        // When - Navigate to detail again (re-entry after swipe)
        detailButton.tap()
        
        // Then - Detail screen is visible again
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2), "Re-entry after swipe should work")
    }
    
    func testMultipleReentries() {
        let mainTitle = app.navigationBars["Main"]
        let detailButton = app.buttons["ShowDetail"]
        let detailTitle = app.navigationBars["Detail"]
        
        // Perform multiple push-pop-push cycles
        for i in 1...3 {
            // Push
            detailButton.tap()
            XCTAssertTrue(detailTitle.waitForExistence(timeout: 2), "Push \(i) failed")
            
            // Pop
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(mainTitle.waitForExistence(timeout: 2), "Pop \(i) failed")
        }
        
        // Final push should still work
        detailButton.tap()
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 2), "Final re-entry should work")
    }
    
    // MARK: - Modal Re-entry Tests
    
    func testModalPresentDismissReentry() {
        // Given - Main screen
        let mainTitle = app.navigationBars["Main"]
        XCTAssertTrue(mainTitle.exists)
        
        // When - Present modal
        let modalButton = app.buttons["ShowModal"]
        XCTAssertTrue(modalButton.exists)
        modalButton.tap()
        
        // Then - Modal is presented
        let modalTitle = app.staticTexts["ModalTitle"]
        XCTAssertTrue(modalTitle.waitForExistence(timeout: 2))
        
        // When - Dismiss modal
        let dismissButton = app.buttons["DismissModal"]
        XCTAssertTrue(dismissButton.exists)
        dismissButton.tap()
        
        // Then - Back to main
        XCTAssertTrue(mainTitle.waitForExistence(timeout: 2))
        
        // When - Present modal again (re-entry)
        modalButton.tap()
        
        // Then - Modal is presented again
        XCTAssertTrue(modalTitle.waitForExistence(timeout: 2), "Modal re-entry should work")
    }
    
    func testModalSwipeDownDismissReentry() {
        // Given - Present modal
        let modalButton = app.buttons["ShowModal"]
        modalButton.tap()
        
        let modalTitle = app.staticTexts["ModalTitle"]
        XCTAssertTrue(modalTitle.waitForExistence(timeout: 2))
        
        // When - Swipe down to dismiss
        app.swipeDown(velocity: .fast)
        
        // Then - Modal dismissed
        let mainTitle = app.navigationBars["Main"]
        XCTAssertTrue(mainTitle.waitForExistence(timeout: 2))
        
        // When - Present modal again
        modalButton.tap()
        
        // Then - Modal re-entry works
        XCTAssertTrue(modalTitle.waitForExistence(timeout: 2), "Modal re-entry after swipe dismiss should work")
    }
    
    // MARK: - Complex Navigation Tests
    
    func testNestedNavigationReentry() {
        // Navigate: Main → Detail → SubDetail
        app.buttons["ShowDetail"].tap()
        XCTAssertTrue(app.navigationBars["Detail"].waitForExistence(timeout: 2))
        
        app.buttons["ShowSubDetail"].tap()
        XCTAssertTrue(app.navigationBars["SubDetail"].waitForExistence(timeout: 2))
        
        // Pop to root
        app.buttons["PopToRoot"].tap()
        XCTAssertTrue(app.navigationBars["Main"].waitForExistence(timeout: 2))
        
        // Re-navigate the same path
        app.buttons["ShowDetail"].tap()
        XCTAssertTrue(app.navigationBars["Detail"].waitForExistence(timeout: 2))
        
        app.buttons["ShowSubDetail"].tap()
        XCTAssertTrue(app.navigationBars["SubDetail"].waitForExistence(timeout: 2), "Nested navigation re-entry should work")
    }
    
    func testMixedNavigationAndModalReentry() {
        // Push navigation
        app.buttons["ShowDetail"].tap()
        XCTAssertTrue(app.navigationBars["Detail"].waitForExistence(timeout: 2))
        
        // Present modal from detail
        app.buttons["ShowModalFromDetail"].tap()
        XCTAssertTrue(app.staticTexts["ModalTitle"].waitForExistence(timeout: 2))
        
        // Dismiss modal
        app.buttons["DismissModal"].tap()
        XCTAssertTrue(app.navigationBars["Detail"].waitForExistence(timeout: 2))
        
        // Pop navigation
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Main"].waitForExistence(timeout: 2))
        
        // Re-do the entire flow
        app.buttons["ShowDetail"].tap()
        XCTAssertTrue(app.navigationBars["Detail"].waitForExistence(timeout: 2))
        
        app.buttons["ShowModalFromDetail"].tap()
        XCTAssertTrue(app.staticTexts["ModalTitle"].waitForExistence(timeout: 2), "Mixed navigation re-entry should work")
    }
}

// MARK: - Hero Animation Re-entry Tests

final class HeroFullScreenReentryUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--hero"]
        app.launch()
    }
    
    func testHeroFullScreenReentry() {
        // Given - Main screen
        let mainTitle = app.navigationBars["Main"]
        XCTAssertTrue(mainTitle.exists)
        
        // When - Present with Hero animation
        let heroButton = app.buttons["ShowHeroFullScreen"]
        XCTAssertTrue(heroButton.exists)
        heroButton.tap()
        
        // Then - Hero screen is presented
        let heroTitle = app.staticTexts["HeroScreenTitle"]
        XCTAssertTrue(heroTitle.waitForExistence(timeout: 3)) // Longer timeout for animation
        
        // When - Dismiss
        let dismissButton = app.buttons["DismissHero"]
        dismissButton.tap()
        
        // Wait for dismiss animation
        XCTAssertTrue(mainTitle.waitForExistence(timeout: 3))
        
        // When - Present again (re-entry)
        heroButton.tap()
        
        // Then - Hero screen is presented again
        XCTAssertTrue(heroTitle.waitForExistence(timeout: 3), "Hero full screen re-entry should work")
    }
    
    func testHeroAnimationMultipleReentries() {
        let heroButton = app.buttons["ShowHeroFullScreen"]
        let heroTitle = app.staticTexts["HeroScreenTitle"]
        let dismissButton = app.buttons["DismissHero"]
        let mainTitle = app.navigationBars["Main"]
        
        // Multiple Hero present/dismiss cycles
        for i in 1...3 {
            // Present
            heroButton.tap()
            XCTAssertTrue(heroTitle.waitForExistence(timeout: 3), "Hero present \(i) failed")
            
            // Dismiss
            dismissButton.tap()
            XCTAssertTrue(mainTitle.waitForExistence(timeout: 3), "Hero dismiss \(i) failed")
        }
        
        // Final present should work
        heroButton.tap()
        XCTAssertTrue(heroTitle.waitForExistence(timeout: 3), "Final Hero re-entry should work")
    }
}

// MARK: - Performance Tests

extension NavigationReentryUITests {
    
    func testReentryPerformance() {
        measure {
            // Push
            app.buttons["ShowDetail"].tap()
            _ = app.navigationBars["Detail"].waitForExistence(timeout: 2)
            
            // Pop
            app.navigationBars.buttons.element(boundBy: 0).tap()
            _ = app.navigationBars["Main"].waitForExistence(timeout: 2)
            
            // Re-entry push
            app.buttons["ShowDetail"].tap()
            _ = app.navigationBars["Detail"].waitForExistence(timeout: 2)
            
            // Pop again
            app.navigationBars.buttons.element(boundBy: 0).tap()
            _ = app.navigationBars["Main"].waitForExistence(timeout: 2)
        }
    }
}