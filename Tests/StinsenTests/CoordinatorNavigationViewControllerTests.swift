import SwiftUI
import UIKit
import XCTest
@testable import Stinsen

@MainActor
final class CoordinatorNavigationViewControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func show(_ viewController: UIViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        self.window = window
        pump()
    }

    private func pump(
        _ duration: TimeInterval = 0.5,
        until condition: (() -> Bool)? = nil
    ) {
        let deadline = Date().addingTimeInterval(duration)
        repeat {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            if condition?() == true { return }
        } while Date() < deadline
    }

    func testUIKitEntryBindsItsAnchorBeforeRendering() {
        let coordinator = NativeRootCoordinator()

        let built = coordinator.viewController()

        XCTAssertTrue(coordinator.host.base === built)
        XCTAssertFalse(built.isViewLoaded, "binding the anchor must not force viewDidLoad")
        XCTAssertTrue(built.children.isEmpty, "the root is installed only when UIKit loads the container")
    }

    func testUIKitRootIsInstalledDirectlyAndLoadsInsideNavigation() {
        let coordinator = NativeRootCoordinator()
        let built = coordinator.viewController()
        let navigation = UINavigationController(rootViewController: built)

        show(navigation)

        XCTAssertTrue(coordinator.rootController.parent === built)
        XCTAssertNotNil(coordinator.rootController.navigationControllerAtLoad,
            "the app root must load after its container has entered the navigation hierarchy")
        XCTAssertFalse(built.children.contains { $0 is ScreenProbe },
            "a Stinsen-owned container reports its own appearance")
        XCTAssertEqual(built.children.count, 1, "there is no hosting/representable round trip")
    }

    func testRouteRecordedBeforeUIKitAppearanceDrainsWhenContainerArrives() {
        let coordinator = SwiftUIRootCoordinator()
        let navigation = coordinator.navigationController()

        coordinator.route(.push, to: Text("pending"))
        XCTAssertEqual(navigation.viewControllers.count, 1)
        XCTAssertEqual(coordinator.stack.value.first?.state, .pending)

        show(navigation)
        pump(until: { navigation.viewControllers.count == 2 })
        pump()

        XCTAssertEqual(navigation.viewControllers.count, 2,
            "the container's own didAppear is the unavailable → ready wake-up")
        XCTAssertEqual(coordinator.stack.value.first?.state, .live)
    }

    func testUIKitRootSwitchReplacesTheContainedController() {
        let coordinator = SwitchingRootCoordinator()
        let built = coordinator.viewController()
        show(built)

        coordinator.root(\.native)
        pump(until: { coordinator.nativeController.parent === built })

        XCTAssertTrue(coordinator.nativeController.parent === built)
        XCTAssertEqual(built.children.count, 1)
        XCTAssertFalse(built.children.first is UIHostingController<AnyView>)
    }

    func testSwiftUIToSwiftUIRootSwitchKeepsOneHostingBoundary() {
        let coordinator = SwitchingRootCoordinator()
        let built = coordinator.viewController()
        show(built)
        let renderer = built.children.first

        coordinator.root(\.alternate, animation: .easeInOut)
        pump()

        XCTAssertTrue(built.children.first === renderer,
            "SwiftUI root transitions stay in one renderer and one transaction tree")
        XCTAssertEqual(built.children.count, 1)
    }

    func testAppOwnedHostingControllerStillProvidesANestedSwiftUIAnchor() {
        let coordinator = SwiftUIRootCoordinator()
        let hosting = UIHostingController(rootView: coordinator.view())
        let navigation = UINavigationController(rootViewController: hosting)

        show(navigation)

        XCTAssertNotNil(coordinator.host.base)
        XCTAssertFalse(coordinator.host.base === hosting,
            "SwiftUI entry keeps a coordinator-local background anchor")

        coordinator.route(.push, to: Text("nested push"))
        pump(until: { navigation.viewControllers.count == 2 })
        pump()
        XCTAssertEqual(navigation.viewControllers.count, 2)
    }

    func testSiblingSwiftUICoordinatorsReceiveDistinctAnchors() {
        let first = SwiftUIRootCoordinator()
        let second = SwiftUIRootCoordinator()
        let hosting = UIHostingController(rootView: HStack {
            first.view()
            second.view()
        })

        show(hosting)

        XCTAssertNotNil(first.host.base)
        XCTAssertNotNil(second.host.base)
        XCTAssertFalse(first.host.base === second.host.base,
            "each inline coordinator owns its own background anchor")
    }

    func testRapidCrossRuntimeRootSwitchesSettleOnOneChild() {
        let coordinator = SwitchingRootCoordinator()
        let built = coordinator.viewController()
        show(built)

        coordinator.root(\.native, animation: .linear(duration: 1))
        coordinator.root(\.alternate, animation: .linear(duration: 1))
        pump()

        XCTAssertEqual(built.children.count, 1,
            "an interrupted container transition must not leave either root attached")
        XCTAssertTrue(built.children.first is UIHostingController<AnyView>)
    }
}

@MainActor
private final class NativeRootCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<NativeRootCoordinator>(initial: \.start)
    let rootController = NavigationAwareRootViewController()

    @Root var start = makeStart

    func makeStart() -> UIViewController { rootController }
}

@MainActor
private final class SwiftUIRootCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<SwiftUIRootCoordinator>(initial: \.start)

    @Root var start = makeStart

    @ViewBuilder func makeStart() -> some View { Text("root") }
}

@MainActor
private final class SwitchingRootCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<SwitchingRootCoordinator>(initial: \.start)
    let nativeController = UIViewController()

    @Root var start = makeStart
    @Root var alternate = makeAlternate
    @Root var native = makeNative

    @ViewBuilder func makeStart() -> some View { Text("start") }
    @ViewBuilder func makeAlternate() -> some View { Text("alternate") }
    func makeNative() -> UIViewController { nativeController }
}

@MainActor
private final class NavigationAwareRootViewController: UIViewController {
    private(set) weak var navigationControllerAtLoad: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationControllerAtLoad = navigationController
    }
}
