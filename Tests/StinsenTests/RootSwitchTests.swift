import XCTest
import SwiftUI
@testable import Stinsen

final class RootSwitchTests: XCTestCase {

    func testRootSwitchDefaultInit() {
        let rs = RootSwitch()
        XCTAssertNotNil(rs)
        XCTAssertEqual(rs.zOrder, .front)
    }

    func testRootSwitchWithTransitionAndZOrderFront() {
        let rs = RootSwitch(.opacity, zOrder: .front)
        XCTAssertEqual(rs.zOrder, .front)
    }

    func testRootSwitchWithZOrderBack() {
        let rs = RootSwitch(.slide, zOrder: .back)
        XCTAssertEqual(rs.zOrder, .back)
    }

    func testRootLayerCases() {
        XCTAssertNotEqual(RootLayer.front, RootLayer.back)
    }
}
