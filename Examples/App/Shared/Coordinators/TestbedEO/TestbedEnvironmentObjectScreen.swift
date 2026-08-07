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

    /// The back-to-back matrix, written with the **imperative** API — the recommended
    /// style. `route(.push, to: someView)` needs no `@Route` declaration, so the screen
    /// is built at the call site.
    ///
    /// Two properties fall out of that and both matter here:
    ///  - Imperative routes mint a fresh id every call, so the "same route twice in a
    ///    row is dropped" behaviour (L1) does not apply. Push → Push needs no second
    ///    declared route to work.
    ///  - ...which also means imperative routes have **no double-tap protection**. The
    ///    host serialises transitions but does not coalesce them, so a double tap
    ///    produces two screens — exactly as in plain UIKit, where debouncing is the
    ///    app's job.
    ///
    /// **Buttons are only ever appended, never inserted.** Reaching one that sits below
    /// the fold means scrolling first, and a screen that is scrolled when a custom
    /// containment presentation attaches to it puts that presentation's own controls out
    /// of reach. Moving an existing button down therefore breaks tests that have nothing
    /// to do with it — measured, not theorised.
    private var combos: [(id: String, title: String, action: () -> Void)] {
        [
            ("PopThenPush", "Pop → Push", {
                coordinator.popLast()
                coordinator.route(.push, to: coordinator.makeScreen())
            }),
            ("PopThenPresent", "Pop → Present", {
                coordinator.popLast()
                coordinator.route(.modal, to: coordinator.makeScreenInNavigationView())
            }),
            ("PopToRootThenPush", "PopToRoot → Push", {
                coordinator.popToRoot()
                coordinator.route(.push, to: coordinator.makeScreen())
            }),
            ("PopToRootThenPresent", "PopToRoot → Present", {
                coordinator.popToRoot()
                coordinator.route(.modal, to: coordinator.makeScreenInNavigationView())
            }),
            ("PushThenPush", "Push → Push", {
                coordinator.route(.push, to: coordinator.makeScreen())
                coordinator.route(.push, to: coordinator.makeScreen())
            }),
            ("PushThenPresent", "Push → Present", {
                coordinator.route(.push, to: coordinator.makeScreen())
                coordinator.route(.modal, to: coordinator.makeScreenInNavigationView())
            }),
            ("PresentThenPush", "Present → Push", {
                coordinator.route(.modal, to: coordinator.makeScreenInNavigationView())
                coordinator.route(.push, to: coordinator.makeScreen())
            }),
            ("PresentThenPresent", "Present → Present", {
                coordinator.route(.modal, to: coordinator.makeScreenInNavigationView())
                coordinator.route(.modal, to: coordinator.makeScreenInNavigationView())
            }),
        ]
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

                // Pop controls live near the top on purpose. This screen is several
                // screenfuls long, and when it is presented as an overlay there are two
                // nested scroll views — so "scroll until the button is hittable" is not
                // reliable for anything far down. Every test needs these, so they must
                // be reachable without scrolling at all.
                HStack {
                    Button("Pop last") { coordinator.popLast() }
                        .accessibilityIdentifier("PopLast")
                    Spacer()
                    Button("Pop to root") { coordinator.popToRoot() }
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

                RoundedButton("Modal coordinator") {
                    coordinator.route(to: \.modalCoordinator)
                }
                .accessibilityIdentifier("ShowModalCoordinator")

                RoundedButton("Push coordinator") {
                    coordinator.route(to: \.pushCoordinator)
                }
                .accessibilityIdentifier("ShowPushCoordinator")

                // A coordinator embedded as a child view rather than routed to — two
                // coordinators behind one enclosing view controller.
                RoundedButton("Embedded coordinator") {
                    coordinator.route(to: \.embeddedCoordinator)
                }
                .accessibilityIdentifier("ShowEmbeddedCoordinator")

                // A custom presentation that attaches by child containment rather than
                // presenting. Does the lifecycle probe still see it?
                RoundedButton("Custom overlay") {
                    coordinator.route(
                        TestbedEnvironmentObjectCoordinator.overlay,
                        to: coordinator.makeScreen()
                    )
                }
                .accessibilityIdentifier("ShowCustomOverlay")

                // A screen with no SwiftUI in it. Routed to exactly like any other, which
                // is the property being demonstrated.
                RoundedButton("UIKit screen") {
                    coordinator.route(.push, to: coordinator.makeUIKitScreen())
                }
                .accessibilityIdentifier("ShowUIKitScreen")

                RoundedButton("UIKit screen (modal)") {
                    coordinator.route(.modal, to: coordinator.makeUIKitScreen())
                }
                .accessibilityIdentifier("ShowUIKitModal")

                Divider().padding(.vertical, 8)

                // MARK: Refactor verification scenarios

                // Back-to-back navigation, every combination.
                //
                // Nothing serialises these today: each call mutates the stack and the
                // observers act on it synchronously, so the second operation is issued
                // while the first one's UIKit transition is still animating. Whether
                // that survives is up to UIKit's tolerance for the specific pairing,
                // which is exactly the kind of thing that works on one iOS version and
                // silently drops a screen on another.
                //
                // Every combo ends in an operation that must produce a NEW screen, so
                // "did a higher serial appear" is a uniform pass condition.
                ForEach(combos, id: \.id) { combo in
                    RoundedButton(combo.title) { combo.action() }
                        .accessibilityIdentifier("Combo-" + combo.id)
                }

                // push → modal, so `popToRoot` has to unwind across a presentation
                // boundary rather than just walking one navigation stack.
                //
                // Deliberately NOT two consecutive pushes of the same route: L1 means
                // `CoordinatorStack.push` silently drops a repeat of the current top,
                // so the example would be demonstrating the bug instead of the feature.
                RoundedButton("Build mixed chain") {
                    coordinator.route(to: \.pushScreen)
                    coordinator.route(to: \.modalScreen)
                }
                .accessibilityIdentifier("BuildMixedChain")

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
