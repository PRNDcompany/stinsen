import SwiftUI
import UIKit
import Stinsen

/// The scenarios, grouped.
///
/// These used to sit on `TestbedEnvironmentObjectScreen` alongside the navigation
/// controls, which pushed that screen past thirty controls and made it unreadable — and
/// the screen is *self-similar* by design, so every one of them was duplicated at every
/// depth of every stack.
///
/// The split is along that line. A control belongs on the testbed screen only if it has
/// to be reachable from any depth (push, pop, sample the state). Everything else is a
/// one-off you run from somewhere, and belongs here.
///
/// Deliberately **not** a testbed screen: it takes no serial number and carries none of
/// the shared identifiers, so pushing it does not shift what the tests are counting.
///
/// A `ScrollView` rather than a `List`, because `List` only builds the rows it is showing
/// — a button below the fold does not exist in the accessibility tree at all, so a UI
/// test cannot even wait for it, let alone scroll to it.
struct TestbedScenariosScreen: View {
    unowned let coordinator: TestbedEnvironmentObjectCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scenarios")
                    .font(.headline)
                    .accessibilityIdentifier("ScenariosScreen")

                // Every screen here is pushed on top of the testbed screen, so tests need
                // a way back down to it.
                Button("Pop last") { coordinator.popLast() }
                    .accessibilityIdentifier("PopLast")

                CoordinatorDiagnostics(coordinator: coordinator)

            Text("Back to back").font(.subheadline).bold()

                ForEach(coordinator.combos, id: \.id) { combo in
                    Button(combo.title) { combo.action() }
                        .accessibilityIdentifier("Combo-" + combo.id)
                }

                // push → modal, so unwinding has to cross a presentation boundary — one
                // dismiss plus one pop — rather than walk a single navigation stack.
                Button("Build mixed chain") {
                    coordinator.route(to: \.pushScreen)
                    coordinator.route(to: \.modalScreen)
                }
                .accessibilityIdentifier("BuildMixedChain")

            Text("Screens that are not SwiftUI").font(.subheadline).bold()

                Button("UIKit screen") {
                    coordinator.route(.push, to: coordinator.makeUIKitScreen())
                }
                .accessibilityIdentifier("ShowUIKitScreen")

                Button("UIKit screen (modal)") {
                    coordinator.route(.modal, to: coordinator.makeUIKitScreen())
                }
                .accessibilityIdentifier("ShowUIKitModal")

                Button("Own hosting controller") {
                    coordinator.route(.push, to: coordinator.makeOwnHostingController())
                }
                .accessibilityIdentifier("ShowOwnHostingController")

                Button("UIKit tabs") {
                    coordinator.route(.modal, to: TestbedTabCoordinator().viewController())
                }
                .accessibilityIdentifier("ShowUIKitTabs")

            Text("Routing to a coordinator").font(.subheadline).bold()

                Button("Push coordinator") {
                    coordinator.route(to: \.pushCoordinator)
                }
                .accessibilityIdentifier("ShowPushCoordinator")

                Button("Modal coordinator") {
                    coordinator.route(to: \.modalCoordinator)
                }
                .accessibilityIdentifier("ShowModalCoordinator")

            // Either side can be either runtime, and the two choices are independent:
            // the host decides whether it asks for `view()` or `viewController()`, and
            // the coordinator decides what its screens are made of.
            Text("Embedding a coordinator as a child").font(.subheadline).bold()

                Button("SwiftUI host, SwiftUI flow") {
                    coordinator.route(.push, to: EmbeddingInSwiftUIScreen(embedsUIKitFlow: false))
                }
                .accessibilityIdentifier("EmbedSwiftUIInSwiftUI")

                Button("SwiftUI host, UIKit flow") {
                    coordinator.route(.push, to: EmbeddingInSwiftUIScreen(embedsUIKitFlow: true))
                }
                .accessibilityIdentifier("EmbedUIKitInSwiftUI")

                Button("UIKit host, SwiftUI flow") {
                    coordinator.route(.push, to: CoordinatorContainerViewController(
                        headerText: "UIKit host",
                        coordinator: EmbeddedSwiftUIFlowCoordinator()
                    ))
                }
                .accessibilityIdentifier("EmbedSwiftUIInUIKit")

                Button("UIKit host, UIKit flow") {
                    coordinator.route(.push, to: CoordinatorContainerViewController(
                        headerText: "UIKit host",
                        coordinator: EmbeddedUIKitFlowCoordinator()
                    ))
                }
                .accessibilityIdentifier("EmbedUIKitInUIKit")

            Text("Presentation and lifecycle").font(.subheadline).bold()

                // Attaches its screen by child containment rather than presenting it —
                // the shape most likely to break lifecycle reporting.
                Button("Custom overlay") {
                    coordinator.route(
                        TestbedEnvironmentObjectCoordinator.overlay,
                        to: coordinator.makeScreen()
                    )
                }
                .accessibilityIdentifier("ShowCustomOverlay")

            Text("Roots").font(.subheadline).bold()

                Button("Switch root") {
                    coordinator.root(\.alternateStart)
                }
                .accessibilityIdentifier("SwitchRoot")

                Button("Switch to UIKit root") {
                    coordinator.root(\.uikitStart)
                }
                .accessibilityIdentifier("SwitchToUIKitRoot")
            }
            .padding()
        }
    }
}

/// What the coordinator believes about itself, sampled on demand.
///
/// On every screen that can be the front one, because a test that has navigated up to a
/// scenario still needs to ask — and popping back down just to sample would change the
/// very state it is asking about.
///
/// Read explicitly rather than straight from `body`: these views hold the coordinator
/// `unowned`, not as an `@ObservedObject`, so SwiftUI has no reason to re-render when the
/// stack changes and a computed label would show whatever was true at the last unrelated
/// redraw.
struct CoordinatorDiagnostics: View {
    unowned let coordinator: TestbedEnvironmentObjectCoordinator

    @State private var stackState = "unsampled"
    @State private var lifecycleState = "unsampled"
    @State private var lifecycleTrail = "unsampled"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stackState).accessibilityIdentifier("StackState")
            Text(lifecycleState).accessibilityIdentifier("LifecycleState")
            Text(lifecycleTrail).accessibilityIdentifier("LifecycleTrail")

            Button("Sample stack state") {
                stackState = coordinator.stack.currentRoute == -1 ? "empty" : "nonempty"
                lifecycleState = coordinator.lastLifecycleEvent
                lifecycleTrail = coordinator.lifecycleTrail
            }
            .accessibilityIdentifier("SampleStackState")

            Button("Reset lifecycle log") {
                coordinator.resetLifecycleLog()
                lifecycleState = "none"
                lifecycleTrail = "none"
            }
            .accessibilityIdentifier("ResetLifecycleLog")
        }
    }
}
