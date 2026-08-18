//
//  ConfigureHookTests.swift
//  StinsenTests
//
//  `configure(_ viewController:)` is the UIKit counterpart to `customize(_ view:)`: the
//  coordinator gets handed the view controller the library built to stand for it.
//
//  That the hook is purely additive is proved at *compile* time by the rest of this suite —
//  every other test coordinator is a silent conformer that implements neither `customize`
//  nor `configure`, so if the claim were wrong the target would not build.
//

import XCTest
@testable import Stinsen
import SwiftUI
import UIKit

@MainActor
final class ConfigureHookTests: XCTestCase {

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    /// Puts a view controller on screen and pumps the run loop, so SwiftUI actually renders.
    private func show(_ viewController: UIViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        self.window = window
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
    }

    // MARK: - The controller the coordinator is handed

    func testViewControllerHandsOverTheControllerItBuilt() {
        let coordinator = ConfiguringCoordinator()

        let built = coordinator.viewController()

        XCTAssertEqual(coordinator.configured.count, 1)
        XCTAssertTrue(coordinator.configured.first === built,
            "the hook must receive the very controller that was returned")
        XCTAssertTrue(built is CoordinatorNavigationViewController<ConfiguringCoordinator>,
            "UIKit entry is represented by the coordinator's own container")
    }

    /// The regression this change could most plausibly cause.
    ///
    /// A SwiftUI root still renders through one hosting boundary on UIKit entry, so its
    /// modifiers and observations remain meaningful. The coordinator itself is native and
    /// receives `configure`; the two hooks apply to their respective parts of the tree.
    func testUIKitEntryPreservesCustomizeForASwiftUIRoot() {
        let coordinator = ConfiguringCoordinator()

        show(coordinator.viewController())

        XCTAssertGreaterThan(coordinator.customizeCalls, 0, "the SwiftUI root kept its modifiers")
        XCTAssertEqual(coordinator.configured.count, 1, "the UIKit hook ran once")
    }

    /// `view()` is the SwiftUI path, and `customize` is the hook there. Pinning the rule
    /// rather than the implementation: each runtime gets its own hook and neither borrows
    /// the other's.
    func testTheSwiftUIPathDoesNotCallConfigure() {
        let coordinator = ConfiguringCoordinator()

        show(UIHostingController(rootView: coordinator.view()))

        XCTAssertGreaterThan(coordinator.customizeCalls, 0, "the SwiftUI hook ran")
        XCTAssertTrue(coordinator.configured.isEmpty, "the UIKit hook did not")
    }

    func testNavigationControllerConfiguresTheRootNotTheNavigationController() {
        let coordinator = ConfiguringCoordinator()

        let navigation = coordinator.navigationController()

        XCTAssertEqual(coordinator.configured.count, 1)
        XCTAssertTrue(coordinator.configured.first === navigation.viewControllers.first,
            "the coordinator's own controller is what it gets, not the container around it")
        XCTAssertFalse(coordinator.configured.first is UINavigationController)
    }

    /// `viewController()` is a factory, and the hook follows that rather than pretending
    /// otherwise. Caching the controller on the coordinator would close a retain cycle —
    /// `CoordinatorTabBarController` holds its coordinator strongly on purpose — and would
    /// hand the same instance to two parents, which UIKit does not allow.
    func testEachCallBuildsAndConfiguresAgain() {
        let coordinator = ConfiguringCoordinator()

        let first = coordinator.viewController()
        let second = coordinator.viewController()

        XCTAssertFalse(first === second, "a factory, so two asks are two controllers")
        XCTAssertEqual(coordinator.configured.count, 2, "each configured once")
    }

    // MARK: - Through the paths that are easy to forget

    func testRoutingToACoordinatorConfiguresItsController() {
        let parent = ConfiguringCoordinator()
        let fixture = HostFixture(coordinator: parent)
        let child = ConfiguringCoordinator()

        parent.route(.modal, to: child)
        fixture.settle(until: { parent.stack.value.first?.viewController != nil })

        XCTAssertEqual(child.configured.count, 1)
        XCTAssertTrue(child.configured.first === parent.stack.value.first?.viewController,
            "routing goes through viewController(), so the hook comes with it")
    }

    /// A coordinator routed through an app's own presentation is rendered as SwiftUI,
    /// because the presentation's `make` closure is typed to receive an `AnyView` and builds
    /// its own container. There is no controller that *is* the coordinator on that path, so
    /// the hook does not fire. Pinned so it cannot be "fixed" by handing over the app's
    /// container, which would make the hook's contract untrue.
    func testAnAppPresentationDoesNotConfigure() {
        let parent = ConfiguringCoordinator()
        let fixture = HostFixture(coordinator: parent)
        let child = ConfiguringCoordinator()

        let containment = AnyPresentationType(
            make: { content, _ -> UIViewController in UIHostingController(rootView: content) },
            present: { host, viewController in
                host.addChild(viewController)
                host.view.addSubview(viewController.view)
                viewController.didMove(toParent: host)
            },
            dismiss: { _ in }
        )

        parent.route(containment, to: child)
        fixture.settle(until: { parent.stack.value.first?.state == .live })

        XCTAssertTrue(child.configured.isEmpty,
            "the container is the app's, not the coordinator's")
    }

    func testErasedCoordinatorStillConfigures() {
        let child = ConfiguringCoordinator()
        let erased = AnyCoordinator(child)

        let built = erased.viewController()

        XCTAssertEqual(child.configured.count, 1, "erasure must not swallow the hook")
        XCTAssertTrue(child.configured.first === built)
    }

    func testWrappedCoordinatorIsStillConfigured() {
        let child = ConfiguringCoordinator()
        let wrapped = NavigationViewCoordinator(child)

        let built = wrapped.viewController()

        XCTAssertEqual(child.configured.count, 1,
            "one controller for wrapper and child, and the child is who configures it")
        XCTAssertTrue(child.configured.first === built)
    }

    // MARK: - Tabs

    func testTabCoordinatorConfiguresItsTabBarController() {
        let tabs = ConfiguringTabCoordinator()
        tabs.setupAllTabs()
        tabs.addTab(Text("one"), tabItem: { _ in Text("one") })

        let built = tabs.viewController()

        XCTAssertTrue(built is UITabBarController)
        XCTAssertEqual(tabs.configured.count, 1)
        XCTAssertTrue(tabs.configured.first === built)
    }

    func testTabsThatAreCoordinatorsAreConfigured() {
        let tabs = ConfiguringTabCoordinator()
        tabs.setupAllTabs()
        let insideTab = ConfiguringCoordinator()
        tabs.addTab(insideTab, tabItem: { _ in Text("tab") })

        let bar = tabs.viewController() as? UITabBarController

        XCTAssertEqual(insideTab.configured.count, 1, "each tab is built through viewController()")
        XCTAssertTrue(insideTab.configured.first === bar?.viewControllers?.first)
    }

    /// The motivating case: a tab supplying its own `UITabBarItem`, which nothing but this
    /// hook could do for a coordinator hosted as a real tab bar controller.
    func testATabCanSupplyItsOwnTabBarItemFromConfigure() {
        let tabs = ConfiguringTabCoordinator()
        tabs.setupAllTabs()
        let insideTab = ConfiguringCoordinator()
        insideTab.tabBarItemToSet = UITabBarItem(title: "mine", image: nil, tag: 0)
        tabs.addTab(insideTab, tabItem: { _ in Text("tab") })

        let bar = tabs.viewController() as? UITabBarController

        XCTAssertEqual(bar?.viewControllers?.first?.tabBarItem.title, "mine",
            "nothing was declared for this tab, so what the tab set for itself stands")
    }

    /// And the precedence rule: a declared `tabBarItem:` outranks the child, because the
    /// parent decides how a child is presented.
    func testADeclaredTabBarItemOutranksConfigure() {
        let tabs = ConfiguringTabCoordinator()
        tabs.setupAllTabs()
        let insideTab = ConfiguringCoordinator()
        insideTab.tabBarItemToSet = UITabBarItem(title: "mine", image: nil, tag: 0)
        tabs.addTab(
            insideTab,
            tabItem: { _ in Text("tab") },
            tabBarItem: { UITabBarItem(title: "declared", image: nil, tag: 0) }
        )

        let bar = tabs.viewController() as? UITabBarController

        XCTAssertEqual(bar?.viewControllers?.first?.tabBarItem.title, "declared")
    }
}

// MARK: - Test Helpers

@MainActor
private final class ConfiguringCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<ConfiguringCoordinator>(initial: \ConfiguringCoordinator.start)

    @Root var start = makeStart

    @ViewBuilder func makeStart() -> some View { Text("root") }

    /// Every controller this coordinator was handed, in order.
    var configured: [UIViewController] = []
    var customizeCalls = 0

    /// Set to have `configure` install it, for the tab-item cases.
    var tabBarItemToSet: UITabBarItem?

    func configure(_ viewController: UIViewController) {
        configured.append(viewController)
        if let tabBarItemToSet {
            viewController.tabBarItem = tabBarItemToSet
        }
    }

    @ViewBuilder func customize(_ view: AnyView) -> some View {
        // Counted from the body rather than from here: `customize` is called once when the
        // view value is built, while what matters is that it is part of what renders.
        view.background(CountingProbe { [weak self] in self?.customizeCalls += 1 })
    }
}

@MainActor
private final class ConfiguringTabCoordinator: TabCoordinatable {
    let child = TabChild(activeTab: 0)

    var configured: [UIViewController] = []

    func configure(_ viewController: UIViewController) {
        configured.append(viewController)
    }
}

/// Reports that it was rendered, so a test can tell "customize was applied" from
/// "customize was called and its result thrown away".
private struct CountingProbe: View {
    let onAppear: () -> Void

    var body: some View {
        Color.clear.onAppear(perform: onAppear)
    }
}
