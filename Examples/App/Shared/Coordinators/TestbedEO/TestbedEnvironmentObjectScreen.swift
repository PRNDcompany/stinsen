import Foundation
import SwiftUI
import Stinsen

/// Unlike the other screens in this example, this one exists specifically to *drive*
/// navigation, so it takes the coordinator itself rather than a callback per action.
///
/// The reference is `unowned` on purpose: the coordinator owns this view through its
/// stack, so a strong reference would be a cycle
/// (coordinator → stack → view → coordinator). A coordinator always outlives the
/// screens it presents, so there is nothing to guard against.
///
/// The accessibility identifiers below are the contract with `NavigationUITests`.
/// Renaming one breaks a UI test, which is the point — these are the only way to
/// exercise real gestures and real UIKit transition timing.
struct TestbedEnvironmentObjectScreen: View {
    unowned let coordinator: TestbedEnvironmentObjectCoordinator
    /// Assigned once, when the coordinator's factory creates this screen.
    /// UI tests read it to tell which screen is currently on top.
    let serial: Int
    @State var text: String = ""
    @State private var stackState: String = "unsampled"
    @State private var lifecycleState: String = "unsampled"
    @State private var lifecycleTrail: String = "unsampled"

    /// Walks to whatever view controller is actually frontmost, the way code outside
    /// the coordinator would have to.
    ///
    /// Descending into *children* matters as much as following presentations: with
    /// SwiftUI hosting, the `UINavigationController` lives inside the window root's
    /// child hierarchy, not above it. Following only `presentedViewController` lands
    /// on the window root, whose `navigationController` is nil — so a "pop" issued
    /// there silently targets nothing.
    static func topmostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        return descend(from: root)
    }

    private static func descend(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController { return descend(from: presented) }
        if let nav = vc as? UINavigationController, let top = nav.topViewController {
            return descend(from: top)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return descend(from: selected)
        }
        if let lastChild = vc.children.last { return descend(from: lastChild) }
        return vc
    }

    var body: some View {
        ScrollView {
            VStack {
                // Unique per screen. UI tests assert on existence rather than trying to
                // work out which of several identical labels is on top — XCUITest query
                // order is not z-order, so "the last match" is not "the front screen".
                Text("Screen \(serial)")
                    .accessibilityIdentifier("Screen-\(serial)")

                // Which coordinator owns this screen. A coordinator route hands the flow
                // to a new instance with its own host, and that hand-off is invisible
                // from the screen contents alone.
                Text("Coordinator \(coordinator.number)")
                    .accessibilityIdentifier("CoordinatorID")

                // What the coordinator *believes* about its stack, sampled on demand.
                //
                // Read explicitly rather than straight from `body`: this view holds the
                // coordinator `unowned`, not as an `@ObservedObject`, so SwiftUI has no
                // reason to re-render when the stack changes. A label computed in `body`
                // would show whatever was true at the last unrelated redraw.
                Text(stackState)
                    .accessibilityIdentifier("StackState")

                RoundedButton("Sample stack state") {
                    stackState = coordinator.stack.currentRoute == -1 ? "empty" : "nonempty"
                    lifecycleState = coordinator.lastLifecycleEvent
                    lifecycleTrail = coordinator.lifecycleTrail
                }
                .accessibilityIdentifier("SampleStackState")

                // The most recent lifecycle event the coordinator was told about.
                // "none" means the probe never fired — which is the whole question.
                Text(lifecycleState)
                    .accessibilityIdentifier("LifecycleState")

                // Everything since the last reset. Needed because the root screen
                // reports its own lifecycle too, so closing a screen is followed by the
                // one underneath reappearing — "the last event" answers a different
                // question than the tests are asking.
                Text(lifecycleTrail)
                    .accessibilityIdentifier("LifecycleTrail")

                RoundedButton("Reset lifecycle log") {
                    coordinator.resetLifecycleLog()
                    lifecycleState = "none"
                    lifecycleTrail = "none"
                }
                .accessibilityIdentifier("ResetLifecycleLog")

                // Everything below has to be reachable from *any* depth, because this
                // screen is self-similar: a push shows another one of it, so a test
                // driving a chain taps these at every level. One-off scenarios live on
                // `TestbedScenariosScreen` instead — keeping them here made this screen
                // thirty controls long and duplicated all of them at every depth.
                HStack {
                    RoundedButton("Pop last") { coordinator.popLast() }
                        .accessibilityIdentifier("PopLast")
                    Spacer()
                    RoundedButton("Pop to root") { coordinator.popToRoot() }
                        .accessibilityIdentifier("PopToRoot")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)

                TextField("Textfield", text: $text)

                RoundedButton("Modal screen") {
                    coordinator.route(to: \.modalScreen)
                }
                .accessibilityIdentifier("ShowModal")

                RoundedButton("Push screen") {
                    coordinator.route(to: \.pushScreen)
                }
                .accessibilityIdentifier("ShowPush")

                // Rebuilds the front screen's containment, the way an app managing its
                // own child view controllers would — taking the lifecycle probe with it,
                // since the probe lives in `children`.
                RoundedButton("Strip child controllers") {
                    guard let nav = TestbedEnvironmentObjectScreen.topmostViewController()?.navigationController,
                          let target = nav.topViewController else { return }
                    for child in target.children {
                        child.willMove(toParent: nil)
                        child.view.removeFromSuperview()
                        child.removeFromParent()
                    }
                }
                .accessibilityIdentifier("StripChildControllers")

                RoundedButton("Scenarios…") {
                    coordinator.route(.push, to: TestbedScenariosScreen(coordinator: coordinator))
                }
                .accessibilityIdentifier("ShowScenarios")

                // Dismiss/pop straight through UIKit, without telling Stinsen.
                // This is what happens whenever anything outside the coordinator closes
                // a screen — a UIKit parent, a system flow, third-party code, or an app
                // that keeps its own reference to the view controller.
                RoundedButton("UIKit dismiss (bypass)") {
                    guard let top = Self.topmostViewController() else { return }
                    top.dismiss(animated: true)
                }
                .accessibilityIdentifier("UIKitDismissBypass")

                RoundedButton("UIKit pop (bypass)") {
                    guard let top = Self.topmostViewController() else { return }
                    top.navigationController?.popViewController(animated: true)
                }
                .accessibilityIdentifier("UIKitPopBypass")

                RoundedButton("Dismiss me!") {
                    coordinator.dismissCoordinator {
                        print("bye!")
                    }
                }
                .accessibilityIdentifier("DismissCoordinator")
            }
        }
    }
}
