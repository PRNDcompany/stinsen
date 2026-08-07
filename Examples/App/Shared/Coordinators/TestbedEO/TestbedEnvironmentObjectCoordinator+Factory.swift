import Foundation
import SwiftUI
import Stinsen

extension TestbedEnvironmentObjectCoordinator {
    @ViewBuilder func makePushScreen() -> some View {
        TestbedEnvironmentObjectScreen(coordinator: self, serial: nextScreenSerial())
    }

    
    @ViewBuilder func makeModalScreen() -> some View {
        NavigationView {
            TestbedEnvironmentObjectScreen(coordinator: self, serial: nextScreenSerial())
        }
    }
    
    func makePushCoordinator() -> TestbedEnvironmentObjectCoordinator {
        return TestbedEnvironmentObjectCoordinator()
    }

    /// Deliberately carries no controls of its own beyond the marker: every testbed
    /// screen uses the same button identifiers, so a host with its own buttons would
    /// make "tap the front screen's button" ambiguous between it and the coordinator
    /// embedded in it.
    @ViewBuilder func makeEmbeddedCoordinatorScreen() -> some View {
        VStack(spacing: 0) {
            Text("Embedded host")
                .accessibilityIdentifier("EmbeddedHost")
            CoordinatorContainerView { TestbedEnvironmentObjectCoordinator() }
        }
    }
    
    func makeModalCoordinator() -> NavigationViewCoordinator<TestbedEnvironmentObjectCoordinator> {
        return NavigationViewCoordinator(TestbedEnvironmentObjectCoordinator())
    }
    
    @ViewBuilder func makeStart() -> some View {
        TestbedEnvironmentObjectScreen(coordinator: self, serial: nextScreenSerial())
    }
}

/// Embeds a coordinator's screens inside an ordinary SwiftUI hierarchy.
///
///     VStack {
///         Text("Header")
///         CoordinatorContainerView { ChildCoordinator() }
///     }
///
/// The `@StateObject` is what the type is really for: a coordinator owns navigation
/// state, so it has to survive the re-initialisations SwiftUI performs on the
/// surrounding view. Constructing it in `body`, or in the enclosing view's initialiser,
/// would throw the flow away on the next redraw.
///
/// Worth having in the example app because it is the shape that puts two coordinators
/// behind the *same* enclosing view controller. Each still gets its own anchor — the
/// introspection controller a representable creates is per coordinator, not per screen —
/// so their records, probes and lifecycle stay separate.
struct CoordinatorContainerView<C: Coordinatable>: View {

    @MainActor
    final class Context: ObservableObject {
        let coordinator: C

        init(coordinator: C) {
            self.coordinator = coordinator
        }
    }

    @StateObject private var context: Context

    init(coordinator: @autoclosure @escaping () -> C) {
        _context = StateObject(wrappedValue: Context(coordinator: coordinator()))
    }

    init(_ coordinator: @escaping () -> C) {
        self.init(coordinator: coordinator())
    }

    var body: some View {
        context.coordinator.view()
    }
}
