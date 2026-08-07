import Foundation
import SwiftUI

import Stinsen

final class TestbedEnvironmentObjectCoordinator: NavigationCoordinatable {
    let stack = NavigationStack(initial: \TestbedEnvironmentObjectCoordinator.start)

    @Root var start = makeStart

    @Route(.modal) var modalScreen = makeModalScreen
    @Route(.push) var pushScreen = makePushScreen
    @Route(.modal) var modalCoordinator = makeModalCoordinator
    @Route(.push) var pushCoordinator = makePushCoordinator

    /// A coordinator embedded as an ordinary child view rather than routed to.
    ///
    /// Two coordinators then live behind the same enclosing view controller, which is
    /// the case that used to hand the child its parent's anchor — and with it the
    /// parent's lifecycle probe, so the child heard nothing about its own screens.
    @Route(.push) var embeddedCoordinator = makeEmbeddedCoordinatorScreen

    /// A custom presentation that does **not** use `present()` at all — it attaches the
    /// screen by child containment, the way an overlay or a hero transition would.
    ///
    /// This is the shape most likely to break lifecycle reporting: the view controller
    /// is never "presented", so `isBeingDismissed` can never be true for it, and it is
    /// only "moving from parent" if the teardown does proper containment removal.
    static let overlay = AnyPresentationType(
        make: { content, _ in UIHostingController(rootView: content) },
        present: { parent, viewController in
            parent.addChild(viewController)
            viewController.view.frame = parent.view.bounds
            viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            viewController.view.backgroundColor = .systemBackground
            parent.view.addSubview(viewController.view)
            viewController.didMove(toParent: parent)
        },
        dismiss: { viewController in
            viewController.willMove(toParent: nil)
            viewController.view.removeFromSuperview()
            viewController.removeFromParent()
        }
    )

    /// Every lifecycle event this coordinator has been told about, newest last.
    /// Read by the UI tests to check the probe actually fires, and with what reason.
    private(set) var lifecycleLog: [String] = []

    var lastLifecycleEvent: String { lifecycleLog.last ?? "none" }

    /// The whole log, for assertions that cannot use "the last event".
    ///
    /// The coordinator's own root screen reports its lifecycle too now, so closing a
    /// screen is routinely followed by the screen underneath reappearing — "the last
    /// event after a back swipe" is `didAppear`, not `didDisappear(popped)`. That is
    /// correct and more informative than before, and it means the question a test should
    /// ask is "was this reported", against a log it cleared beforehand.
    var lifecycleTrail: String { lifecycleLog.isEmpty ? "none" : lifecycleLog.joined(separator: ",") }

    func resetLifecycleLog() { lifecycleLog.removeAll() }

    /// Builds a screen for the imperative API, which needs a value rather than a
    /// declaration. Imperative routing is the recommended style — see the combo
    /// matrix in `TestbedEnvironmentObjectScreen`.
    @MainActor
    func makeScreen() -> some View {
        TestbedEnvironmentObjectScreen(coordinator: self, serial: nextScreenSerial())
    }

    @MainActor
    func makeScreenInNavigationView() -> some View {
        NavigationView { makeScreen() }
    }

    /// A screen that is a plain `UIViewController`, built the way a UIKit app builds one.
    @MainActor
    func makeUIKitScreen() -> UIViewController {
        UIKitTestbedViewController(coordinator: self, serial: nextScreenSerial())
    }

    /// Every screen gets a number, so UI tests can tell *which* screen is on top.
    /// Without it every testbed screen looks identical to XCUITest and "did the push
    /// actually happen" is unanswerable.
    ///
    /// Counted per process rather than per coordinator. A child coordinator is a fresh
    /// instance, so a per-instance counter would start it back at 1 and put a second
    /// "Screen-1" on screen — every existence-based assertion would then be matching two
    /// different screens without saying so.
    private static var screenSerial = 0

    func nextScreenSerial() -> Int {
        Self.screenSerial += 1
        return Self.screenSerial
    }

    /// Which coordinator instance this is, in creation order.
    ///
    /// Routing *to a coordinator* hands the flow to a different object with its own
    /// host, and that is the whole point of the route — so a test has to be able to see
    /// that the screen in front belongs to someone else.
    private static var coordinatorSerial = 0

    let number: Int = {
        TestbedEnvironmentObjectCoordinator.coordinatorSerial += 1
        return TestbedEnvironmentObjectCoordinator.coordinatorSerial
    }()

    deinit {
        print("Deinit TestbedEnvironmentObjectCoordinator")
    }
}

// MARK: - Lifecycle

extension TestbedEnvironmentObjectCoordinator: CoordinatorLifecycleAware {
    func screenWillAppear(_ route: RouteKey, viewController: UIViewController, animated: Bool) {
        lifecycleLog.append("willAppear")
    }

    func screenDidAppear(_ route: RouteKey, viewController: UIViewController, animated: Bool) {
        lifecycleLog.append("didAppear")
    }

    func screenWillDisappear(_ route: RouteKey, viewController: UIViewController, animated: Bool) {
        lifecycleLog.append("willDisappear")
    }

    func screenDidDisappear(_ route: RouteKey, viewController: UIViewController, reason: ScreenDisappearReason) {
        lifecycleLog.append("didDisappear(\(reason))")
    }
}
