import SwiftUI
import XCTest

@testable import Stinsen

final class TabCoordinatableTests: XCTestCase {
    func testTabCoordinatorIsReleasedAfterSetupAllTabs() {
        weak var weakCoordinator: TestTabCoordinator?

        autoreleasepool {
            let coordinator = TestTabCoordinator()
            coordinator.setupAllTabs()
            weakCoordinator = coordinator
        }

        XCTAssertNil(weakCoordinator)
    }
}

private final class TestTabCoordinator: TabCoordinatable {
    var child = TabChild(startingItems: [\TestTabCoordinator.first])

    @Route(tabItem: makeTabItem, onTapped: onTappedFirst) var first = makeFirst

    func makeFirst() -> some View {
        EmptyView()
    }

    @ViewBuilder func makeTabItem(isActive: Bool) -> some View {
        EmptyView()
    }

    func onTappedFirst(_ isRepeat: Bool, view: AnyView) {}
}
