import Foundation
import SwiftUI
import UIKit
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

/// A screen with no SwiftUI in it at all.
///
/// The point of the testbed's other screens is to exercise navigation; the point of this
/// one is to prove the coordinator does not care which runtime a screen came from. It is
/// handed to `route(_:to:)` as a plain `UIViewController` and gets the same treatment as
/// any other screen — lifecycle callbacks, a place in `popLast()` / `popToRoot()`, and
/// the same behaviour when something else closes it.
///
/// It can push both kinds, so a chain can alternate between runtimes. That is the case
/// worth measuring: a stack whose screens are all one kind proves much less.
final class UIKitTestbedViewController: UIViewController {

    private unowned let coordinator: TestbedEnvironmentObjectCoordinator
    private let serial: Int

    init(coordinator: TestbedEnvironmentObjectCoordinator, serial: Int) {
        self.coordinator = coordinator
        self.serial = serial
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Same identifier scheme as the SwiftUI screens, so the UI tests cannot tell
        // them apart by accident — which is the property under test.
        let title = UILabel()
        title.text = "Screen \(serial) (UIKit)"
        title.accessibilityIdentifier = "Screen-\(serial)"

        let kind = UILabel()
        kind.text = "UIKit screen"
        kind.accessibilityIdentifier = "ScreenKind"

        let stack = UIStackView(arrangedSubviews: [
            title,
            kind,
            button("Push UIKit", "UIKitPushUIKit") { [unowned self] in
                coordinator.route(.push, to: coordinator.makeUIKitScreen())
            },
            button("Push SwiftUI", "UIKitPushSwiftUI") { [unowned self] in
                coordinator.route(.push, to: coordinator.makeScreen())
            },
            button("Modal UIKit", "UIKitModal") { [unowned self] in
                coordinator.route(.modal, to: coordinator.makeUIKitScreen())
            },
            button("Pop last", "UIKitPopLast") { [unowned self] in
                coordinator.popLast()
            },
            button("Pop to root", "UIKitPopToRoot") { [unowned self] in
                coordinator.popToRoot()
            },
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
        ])
    }

    private func button(_ title: String, _ identifier: String, _ action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
}
