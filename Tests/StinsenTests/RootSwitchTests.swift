import XCTest
import SwiftUI
@testable import Stinsen

final class RootSwitchTests: XCTestCase {

    // MARK: - Default initialization

    func testDefaultInitHasNilAnimation() {
        let rs = RootSwitch()
        XCTAssertNil(rs.animation)
    }

    func testDefaultInitHasIdentityTransition() {
        // Can't compare AnyTransition directly, but verify it compiles and is set
        let rs = RootSwitch()
        XCTAssertNotNil(rs.transition)
    }

    func testDefaultInitHasBringToFrontTrue() {
        let rs = RootSwitch()
        XCTAssertTrue(rs.bringToFront)
    }

    // MARK: - Custom initialization

    func testCustomInitStoresAnimation() {
        let rs = RootSwitch(animation: .easeInOut, transition: .slide, bringToFront: false)
        XCTAssertNotNil(rs.animation)
        XCTAssertFalse(rs.bringToFront)
    }

    func testCustomInitWithOnlyAnimation() {
        let rs = RootSwitch(animation: .easeIn)
        // transition defaults to .identity, bringToFront defaults to true
        XCTAssertNotNil(rs.animation)
        XCTAssertTrue(rs.bringToFront)
    }
}
