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

    /// A `UIHostingController` the app built itself, rather than one the library built.
    ///
    /// This is the answer to "SwiftUI content, but I need my own environment": the
    /// environment does not cross a hosting controller boundary, so a screen that needs
    /// one injects it here, where it owns the controller. Routing to it is no different
    /// from routing to any other view controller.
    @MainActor
    func makeOwnHostingController() -> UIViewController {
        let serial = nextScreenSerial()
        let controller = UIHostingController(
            rootView: VStack {
                Text("Screen \(serial)")
                    .accessibilityIdentifier("Screen-\(serial)")
                InjectedValueLabel()
                Button("Pop last") { [unowned self] in popLast() }
                    .accessibilityIdentifier("PopLast")
            }
            .environment(\.injectedNote, "injected")
        )
        controller.view.backgroundColor = .systemBackground
        return controller
    }

    /// A root built the way a UIKit app builds one — no SwiftUI anywhere in it.
    func makeUIKitStart() -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "UIKit root"
        label.accessibilityIdentifier = "UIKitRoot"
        label.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            label.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor, constant: 40),
        ])
        return controller
    }

    /// Deliberately not a testbed screen: it carries none of the shared identifiers, so
    /// "did the root actually change" is answerable without disambiguating anything.
    @ViewBuilder func makeAlternateStart() -> some View {
        VStack {
            Text("Alternate root")
                .accessibilityIdentifier("AlternateRoot")
        }
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

/// Reads a value that only exists if the app's own hosting controller injected it.
private struct InjectedValueLabel: View {
    @Environment(\.injectedNote) private var note

    var body: some View {
        Text(note)
            .accessibilityIdentifier("InjectedNote")
    }
}

private struct InjectedNoteKey: EnvironmentKey {
    static let defaultValue = "not-injected"
}

extension EnvironmentValues {
    var injectedNote: String {
        get { self[InjectedNoteKey.self] }
        set { self[InjectedNoteKey.self] = newValue }
    }
}


/// A small tab coordinator, declared for **both** hosts.
///
/// Each tab carries a SwiftUI `tabItem:` and a `tabBarItem:`. Neither can be derived from
/// the other — a SwiftUI view is not a `UITabBarItem` — so a coordinator that wants to be
/// hostable either way says both, once.
final class TestbedTabCoordinator: TabCoordinatable {
    let child = TabChild(startingItems: [
        \TestbedTabCoordinator.first,
        \TestbedTabCoordinator.second,
    ])

    @Route(tabItem: makeFirstTab, tabBarItem: makeFirstTabBarItem)
    var first = makeFirstScreen

    @Route(tabItem: makeSecondTab, tabBarItem: makeSecondTabBarItem)
    var second = makeSecondScreen

    @ViewBuilder func makeFirstScreen() -> some View {
        Text("Tab one").accessibilityIdentifier("TabOneContent")
    }

    @ViewBuilder func makeSecondScreen() -> some View {
        Text("Tab two").accessibilityIdentifier("TabTwoContent")
    }

    @ViewBuilder func makeFirstTab(isActive: Bool) -> some View {
        Text("One")
    }

    @ViewBuilder func makeSecondTab(isActive: Bool) -> some View {
        Text("Two")
    }

    func makeFirstTabBarItem() -> UITabBarItem {
        let item = UITabBarItem(title: "One", image: UIImage(systemName: "1.circle"), tag: 0)
        item.accessibilityIdentifier = "TabOne"
        return item
    }

    func makeSecondTabBarItem() -> UITabBarItem {
        let item = UITabBarItem(title: "Two", image: UIImage(systemName: "2.circle"), tag: 1)
        item.accessibilityIdentifier = "TabTwo"
        return item
    }
}

