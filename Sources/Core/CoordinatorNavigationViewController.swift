import Combine
import SwiftUI
import UIKit

/// A `NavigationCoordinatable` as UIKit sees it.
///
/// The controller is both the coordinator's stable navigation anchor and the owner of its
/// active root. A SwiftUI root crosses the runtime boundary once through its own hosting
/// controller; a UIKit root is installed directly. In particular, UIKit content no longer
/// makes the round trip UIKit → SwiftUI representable → hosting controller → UIKit.
///
/// The SwiftUI entry point does not use this type. `coordinator.view()` continues to
/// compose the root in the caller's SwiftUI tree and keeps its per-coordinator background
/// anchor, which is required for coordinators embedded in app-owned hosting controllers.
@MainActor
final class CoordinatorNavigationViewController<Coordinator: NavigationCoordinatable>:
    UIViewController,
    ScreenLifecycleReporting
{
    /// Strong on purpose: this controller is the coordinator's UIKit representation.
    private let coordinator: Coordinator
    private let root: NavigationRoot

    let screenLifecycleReporter = ScreenLifecycleReporter()

    private var rootSubscription: AnyCancellable?
    private var activeChild: UIViewController?
    private var activeSlotIndex: Int
    private var activeZIndex: Double
    private var activeRenderingKind: RootRenderingKind
    private var rootTransition: RootTransition?

    private enum RootRenderingKind {
        case swiftUI
        case viewController
    }

    /// A root transition is explicit state rather than an animation completion's captured
    /// locals. Root selection is ordinary application state and can change again while a
    /// cross-runtime animation is still running; settling the current transition first
    /// keeps containment at exactly one active child instead of letting two completions
    /// race to install different roots.
    private struct RootTransition {
        let id: UUID
        let from: UIViewController
        let to: UIViewController
        let forwardsAppearance: Bool
    }

    init(coordinator: Coordinator) {
        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }

        self.coordinator = coordinator
        self.root = coordinator.stack.root
        self.activeSlotIndex = root.activeSlotIndex
        self.activeZIndex = root.activeSlot?.zIndex ?? 0
        self.activeRenderingKind = Self.renderingKind(for: root.activeSlot?.item)
        super.init(nibName: nil, bundle: nil)

        // Binding in init is the point of this boundary. Routes issued before the first
        // layout are retained as pending, and appearance below is the deterministic
        // wake-up once this controller actually reaches a hierarchy.
        coordinator.host.bind(base: self)
        coordinator.configure(self)

        rootSubscription = root.objectWillChange.sink { [weak self] in
            self?.rootDidChange()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let view = UIView(frame: .zero)
        view.backgroundColor = .systemBackground
        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installActiveRoot()
    }

    // MARK: Appearance

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screenLifecycleReporter.viewWillAppear(self, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        screenLifecycleReporter.viewDidAppear(self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        screenLifecycleReporter.viewWillDisappear(self, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        screenLifecycleReporter.viewDidDisappear(self, animated: animated)
    }

    // MARK: Root containment

    private func rootDidChange() {
        let previousSlotIndex = activeSlotIndex
        let previousZIndex = activeZIndex
        let previousRenderingKind = activeRenderingKind
        activeSlotIndex = root.activeSlotIndex
        activeZIndex = root.activeSlot?.zIndex ?? previousZIndex
        activeRenderingKind = Self.renderingKind(for: root.activeSlot?.item)

        guard isViewLoaded else { return }
        // One hosting controller owns all SwiftUI → SwiftUI root changes. Keeping it is
        // what preserves the shared transaction and the route's `AnyTransition` instead
        // of approximating them with a UIKit cross-fade.
        guard previousRenderingKind != .swiftUI || activeRenderingKind != .swiftUI else {
            return
        }
        replaceActiveRoot(
            animated: previousSlotIndex != activeSlotIndex,
            placesNewRootInFront: activeZIndex >= previousZIndex
        )
    }

    private func installActiveRoot() {
        guard activeChild == nil, let child = makeActiveRootController() else { return }
        addChild(child)
        sizeToFill(child.view)
        view.addSubview(child.view)
        child.didMove(toParent: self)
        activeChild = child
    }

    private func replaceActiveRoot(animated: Bool, placesNewRootInFront: Bool) {
        finishActiveRootTransition()

        guard let newChild = makeActiveRootController() else { return }
        guard let oldChild = activeChild else {
            install(child: newChild)
            return
        }
        guard oldChild !== newChild else { return }

        oldChild.willMove(toParent: nil)
        addChild(newChild)
        // Load the incoming view only after containment is established. App-owned root
        // controllers commonly inspect `navigationController` in `viewDidLoad`; loading
        // before `addChild` would make that nil even though UIKit entry is already inside
        // a navigation controller.
        sizeToFill(newChild.view)

        let forwardsAppearance = viewIfLoaded?.window != nil
        let performsAnimation = animated && forwardsAppearance
        if placesNewRootInFront {
            newChild.view.alpha = performsAnimation ? 0 : 1
            view.addSubview(newChild.view)
        } else {
            newChild.view.alpha = 1
            view.insertSubview(newChild.view, belowSubview: oldChild.view)
        }

        if forwardsAppearance {
            oldChild.beginAppearanceTransition(false, animated: performsAnimation)
            newChild.beginAppearanceTransition(true, animated: performsAnimation)
        }

        let transition = RootTransition(
            id: UUID(),
            from: oldChild,
            to: newChild,
            forwardsAppearance: forwardsAppearance
        )
        rootTransition = transition

        guard performsAnimation else {
            finishActiveRootTransition(id: transition.id)
            return
        }

        UIView.animate(
            withDuration: 0.25,
            animations: {
                if placesNewRootInFront {
                    newChild.view.alpha = 1
                } else {
                    oldChild.view.alpha = 0
                }
            },
            completion: { [weak self] _ in
                self?.finishActiveRootTransition(id: transition.id)
            }
        )
    }

    /// Completes the current containment transaction exactly once.
    ///
    /// Calling without an id is the interruption path used before starting a newer root
    /// switch. An animation completion supplies its id, so a completion from an older,
    /// interrupted transition cannot tear down the newer child.
    private func finishActiveRootTransition(id: UUID? = nil) {
        guard let transition = rootTransition else { return }
        guard id == nil || transition.id == id else { return }
        rootTransition = nil

        transition.from.view.layer.removeAllAnimations()
        transition.to.view.layer.removeAllAnimations()
        transition.to.view.alpha = 1

        transition.from.view.removeFromSuperview()
        transition.from.removeFromParent()
        transition.to.didMove(toParent: self)
        activeChild = transition.to

        // End after containment reflects the finished hierarchy. A child coordinator's
        // reporter can then distinguish removal from a mere cover by observing that its
        // former parent no longer owns it.
        if transition.forwardsAppearance {
            transition.from.endAppearanceTransition()
            transition.to.endAppearanceTransition()
        }
    }

    private func install(child: UIViewController) {
        addChild(child)
        sizeToFill(child.view)
        view.addSubview(child.view)
        child.didMove(toParent: self)
        activeChild = child
    }

    private func makeActiveRootController() -> UIViewController? {
        guard let item = root.activeSlot?.item else { return nil }
        switch activeRenderingKind {
        case .swiftUI:
            // This is the UIKit boundary for a SwiftUI root, but the root switch remains
            // inside one SwiftUI renderer. `customize` still has meaning here: modifiers,
            // environment and observation apply to the SwiftUI portion of a UIKit-hosted
            // coordinator. A native UIViewController root deliberately bypasses it.
            return UIHostingController(rootView: AnyView(
                coordinator.customize(AnyView(
                    NavigationRootView(root: root, coordinator: coordinator)
                ))
            ))
        case .viewController:
            return item.child.viewController()
        }
    }

    private static func renderingKind(for item: NavigationRootItem?) -> RootRenderingKind {
        guard let child = item?.child else { return .swiftUI }
        if child is any Coordinatable { return .viewController }
        if let screen = child as? Screen {
            switch screen {
            case .view:
                return .swiftUI
            case .viewController, .coordinator:
                return .viewController
            }
        }
        return .swiftUI
    }

    private func sizeToFill(_ childView: UIView) {
        childView.frame = view.bounds
        childView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}
