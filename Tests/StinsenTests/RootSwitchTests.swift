import XCTest
import SwiftUI
@testable import Stinsen

final class RootSwitchTests: XCTestCase {

    func testRootSwitchInitializes() {
        // RootSwitch is a marker type with no stored properties
        let rs = RootSwitch()
        XCTAssertNotNil(rs)
    }
}
