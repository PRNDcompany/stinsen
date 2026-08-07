//
//  TabCoordinatableTests.swift
//  StinsenTests
//

import XCTest
@testable import Stinsen
import SwiftUI

@MainActor
final class TabCoordinatableTests: XCTestCase {

    // MARK: - Imperative Tab API Tests

    func testAddTabViewIncreasesTabCount() {
        let coordinator = ImperativeTabCoordinator()
        coordinator.setupAllTabs()

        XCTAssertEqual(coordinator.child.allItems.count, 0)

        coordinator.addTab(Text("Tab 1"), tabItem: { _ in Text("T1") })
        XCTAssertEqual(coordinator.child.allItems.count, 1)

        coordinator.addTab(Text("Tab 2"), tabItem: { _ in Text("T2") })
        XCTAssertEqual(coordinator.child.allItems.count, 2)
    }

    func testAddTabCoordinatorIncreasesTabCount() {
        let coordinator = ImperativeTabCoordinator()
        coordinator.setupAllTabs()

        let child = TestChildCoordinator()
        coordinator.addTab(child, tabItem: { _ in Text("T1") })

        XCTAssertEqual(coordinator.child.allItems.count, 1)
    }

    func testFirstAddedTabBecomesActive() {
        let coordinator = ImperativeTabCoordinator()
        coordinator.setupAllTabs()

        coordinator.addTab(Text("Tab 1"), tabItem: { _ in Text("T1") })

        XCTAssertNotNil(coordinator.child.activeItem)
        XCTAssertEqual(coordinator.child.activeTab, 0)
    }

    func testSelectTabChangesActiveTab() {
        let coordinator = ImperativeTabCoordinator()
        coordinator.setupAllTabs()

        coordinator.addTab(Text("Tab 1"), tabItem: { _ in Text("T1") })
        coordinator.addTab(Text("Tab 2"), tabItem: { _ in Text("T2") })

        coordinator.selectTab(1)
        XCTAssertEqual(coordinator.child.activeTab, 1)

        coordinator.selectTab(0)
        XCTAssertEqual(coordinator.child.activeTab, 0)
    }

    func testOnTappedCalledWithIsRepeat() {
        let coordinator = ImperativeTabCoordinator()
        coordinator.setupAllTabs()

        var tappedRepeat: Bool?
        coordinator.addTab(Text("Tab 1"), tabItem: { _ in Text("T1") }, onTapped: { isRepeat in
            tappedRepeat = isRepeat
        })
        coordinator.addTab(Text("Tab 2"), tabItem: { _ in Text("T2") })

        // Select same tab again → isRepeat = true
        coordinator.selectTab(0)
        XCTAssertEqual(tappedRepeat, true)

        // Select different tab → isRepeat = false
        coordinator.selectTab(1)
        coordinator.selectTab(0)
        XCTAssertEqual(tappedRepeat, false)
    }

    // MARK: - TabChild Tests

    func testTabChildActiveTabDidSetTriggersOnTapped() {
        let child = TabChild(activeTab: 0)
        var tappedCount = 0

        child.allItems = [
            TabChildItem(
                presentable: AnyView(Text("A")),
                keyPathIsEqual: { _ in false },
                tabItem: { _ in AnyView(EmptyView()) },
                tabBarItem: { nil },
                onTapped: { _ in tappedCount += 1 }
            ),
            TabChildItem(
                presentable: AnyView(Text("B")),
                keyPathIsEqual: { _ in false },
                tabItem: { _ in AnyView(EmptyView()) },
                tabBarItem: { nil },
                onTapped: { _ in tappedCount += 1 }
            )
        ]
        child.activeItem = child.allItems[0]

        child.activeTab = 1
        XCTAssertEqual(tappedCount, 1)
    }

    func testTabChildAllItemViewsReturnsNilWhenNoItems() {
        let child = TabChild(startingItems: [], activeTab: 0)
        XCTAssertNil(child.allItemViews)
    }

    func testTabChildImperativeInitStartsEmpty() {
        let child = TabChild(activeTab: 0)
        XCTAssertNotNil(child.allItems)
        XCTAssertTrue(child.allItems.isEmpty)
    }
}

// MARK: - Test Helpers

@MainActor
final class ImperativeTabCoordinator: TabCoordinatable {
    let child = TabChild(activeTab: 0)
}
