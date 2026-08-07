import SwiftUI
import UIKit
import Stinsen

// A coordinator's screens can be embedded inside something else rather than routed to.
// There are four combinations, because either side can be either runtime, and each one
// fails differently when it is wrong:
//
//                        │ embedded coordinator's screens are…
//   the thing hosting it │ SwiftUI                    UIKit
//   ─────────────────────┼──────────────────────────────────────────────
//   a SwiftUI view       │ CoordinatorContainerView   CoordinatorContainerView
//   a UIViewController   │ addChild(…viewController())  addChild(…viewController())
//
// The host side decides how the coordinator is asked for its screens — `view()` or
// `viewController()` — and the coordinator side decides what those screens are made of.
// The two are independent, which is the point.

// MARK: - Coordinators to embed

/// A flow whose screens are SwiftUI views.
final class EmbeddedSwiftUIFlowCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack(initial: \EmbeddedSwiftUIFlowCoordinator.start)

    @Root var start = makeStart

    @ViewBuilder func makeStart() -> some View {
        VStack(spacing: 8) {
            Text("SwiftUI flow")
                .accessibilityIdentifier("EmbeddedSwiftUIFlow")

            Button("Present from here") { [unowned self] in
                route(.modal, to: Text("Presented by the SwiftUI flow")
                    .accessibilityIdentifier("EmbeddedFlowPresented"))
            }
            .accessibilityIdentifier("EmbeddedFlowPresent")

            Button("Close it") { [unowned self] in popLast() }
                .accessibilityIdentifier("EmbeddedFlowPopLast")
        }
    }
}

/// The same flow, with screens that are plain view controllers.
final class EmbeddedUIKitFlowCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack(initial: \EmbeddedUIKitFlowCoordinator.start)

    @Root var start = makeStart

    func makeStart() -> UIViewController {
        EmbeddedUIKitFlowViewController(coordinator: self)
    }
}

/// The `EmbeddedUIKitFlowCoordinator`'s root, built the way a UIKit app builds one.
final class EmbeddedUIKitFlowViewController: UIViewController {

    private unowned let coordinator: EmbeddedUIKitFlowCoordinator

    init(coordinator: EmbeddedUIKitFlowCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()

        let label = UILabel()
        label.text = "UIKit flow"
        label.accessibilityIdentifier = "EmbeddedUIKitFlow"

        let present = UIButton(type: .system)
        present.setTitle("Present from here", for: .normal)
        present.accessibilityIdentifier = "EmbeddedFlowPresent"
        present.addAction(UIAction { [unowned self] _ in
            let presented = UIViewController()
            presented.view.backgroundColor = .systemBackground
            let inner = UILabel()
            inner.text = "Presented by the UIKit flow"
            inner.accessibilityIdentifier = "EmbeddedFlowPresented"
            inner.translatesAutoresizingMaskIntoConstraints = false
            presented.view.addSubview(inner)
            NSLayoutConstraint.activate([
                inner.centerXAnchor.constraint(equalTo: presented.view.centerXAnchor),
                inner.centerYAnchor.constraint(equalTo: presented.view.centerYAnchor),
            ])
            coordinator.route(.modal, to: presented)
        }, for: .touchUpInside)

        let close = UIButton(type: .system)
        close.setTitle("Close it", for: .normal)
        close.accessibilityIdentifier = "EmbeddedFlowPopLast"
        close.addAction(UIAction { [unowned self] _ in coordinator.popLast() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, present, close])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
        ])
    }
}

// MARK: - Hosts

/// Embeds a coordinator's screens inside an ordinary SwiftUI hierarchy.
///
///     VStack {
///         Text("Header")
///         CoordinatorContainerView { ChildCoordinator() }
///     }
///
/// The `@StateObject` is what the type is really for: a coordinator owns navigation
/// state, so it has to survive the re-initialisations SwiftUI performs on the surrounding
/// view. Constructing it in `body`, or in the enclosing view's initialiser, would throw
/// the flow away on the next redraw.
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

/// Embeds a coordinator's screens inside a `UIViewController`, by containment.
///
/// The UIKit counterpart of `CoordinatorContainerView`, and the same responsibility: the
/// coordinator is created once and held for as long as the host lives, because a
/// coordinator that is rebuilt has forgotten where the user was.
final class CoordinatorContainerViewController: UIViewController {

    private let coordinator: any Coordinatable
    private let headerText: String

    init(headerText: String, coordinator: any Coordinatable) {
        self.coordinator = coordinator
        self.headerText = headerText
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let header = UILabel()
        header.text = headerText
        header.accessibilityIdentifier = "EmbeddingHost"
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        // The whole demonstration is these four lines. Asking the coordinator for a view
        // controller and adding it as a child is all "embed a flow here" means.
        let child = coordinator.viewController()
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        child.didMove(toParent: self)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            child.view.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

/// The SwiftUI-hosted half of the matrix, as a screen.
struct EmbeddingInSwiftUIScreen: View {
    let embedsUIKitFlow: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("SwiftUI host")
                .accessibilityIdentifier("EmbeddingHost")

            if embedsUIKitFlow {
                CoordinatorContainerView { EmbeddedUIKitFlowCoordinator() }
            } else {
                CoordinatorContainerView { EmbeddedSwiftUIFlowCoordinator() }
            }
        }
    }
}
