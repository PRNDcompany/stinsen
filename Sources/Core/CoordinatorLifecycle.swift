import UIKit

/// Why a screen went away.
///
/// None of this used to be available. Dismissal was inferred from the `deinit` of an
/// object planted on the view controller, which fired whenever ARC got around to
/// releasing it: that told you *that* a screen was gone, long after the fact, and never
/// why — "the user swiped back", "we popped it" and "a modal covered it" were
/// indistinguishable.
public enum ScreenDisappearReason: Hashable, Sendable {
    /// Popped off a navigation stack — back button, back swipe, or a programmatic pop.
    case popped
    /// Dismissed as a presentation — swipe-down on a sheet, or a programmatic dismiss.
    case dismissed
    /// Still alive, just not visible: a modal covered it, or its tab was switched away.
    /// **The screen is still on the stack.**
    case covered
    /// Left the hierarchy some other way, or was removed while already off-screen.
    ///
    /// Middle screens report this rather than `.popped`: they had already disappeared
    /// when they were covered, so UIKit sends no second disappearance when they are
    /// finally removed. Anything doing "the screen closed" work must handle
    /// `.popped`, `.dismissed` **and** `.detached`.
    case detached
}

/// Opt-in screen lifecycle for a coordinator.
///
/// Every requirement has a no-op default, so conforming is free and existing
/// coordinators are unaffected.
///
/// `viewController` is passed alongside `route` because the route alone cannot identify
/// *which* screen this is: drilling from one product detail into another gives both
/// screens the same route. The view controller is the occurrence identity, and for a
/// UIKit-based app it is directly useful besides.
@MainActor
public protocol CoordinatorLifecycleAware: AnyObject {
    func screenWillAppear(_ route: RouteKey, viewController: UIViewController, animated: Bool)
    func screenDidAppear(_ route: RouteKey, viewController: UIViewController, animated: Bool)
    func screenWillDisappear(_ route: RouteKey, viewController: UIViewController, animated: Bool)
    func screenDidDisappear(_ route: RouteKey, viewController: UIViewController, reason: ScreenDisappearReason)
}

public extension CoordinatorLifecycleAware {
    func screenWillAppear(_ route: RouteKey, viewController: UIViewController, animated: Bool) {}
    func screenDidAppear(_ route: RouteKey, viewController: UIViewController, animated: Bool) {}
    func screenWillDisappear(_ route: RouteKey, viewController: UIViewController, animated: Bool) {}
    func screenDidDisappear(_ route: RouteKey, viewController: UIViewController, reason: ScreenDisappearReason) {}
}

// MARK: - Probe

/// Receives lifecycle events observed by a `ScreenProbe`.
@MainActor
protocol ScreenLifecycleReceiver: AnyObject {
    func screenProbeDidObserve(
        _ event: ScreenProbe.Event,
        probe: ScreenProbe,
        route: RouteKey,
        host: UIViewController,
        animated: Bool
    )
}

/// An invisible child view controller that reports its host's appearance callbacks.
///
/// The view controllers a coordinator presents are not always ours: the `make:` closure
/// of a custom presentation returns whatever the app wants, and the `present:` closure
/// is typed to that concrete class, so we cannot wrap or subclass it. Method swizzling
/// would work but sprays side effects across the whole process, which is not something a
/// library should do to its host app.
///
/// UIKit already solves this. `shouldAutomaticallyForwardAppearanceMethods` defaults to
/// `true`, so a child view controller receives the parent's appearance callbacks. Adding
/// an invisible child is therefore enough to observe any view controller, without
/// touching its type or its behaviour — the same technique the SwiftUI anchor uses.
///
/// The one case this does not cover: a container that sets
/// `shouldAutomaticallyForwardAppearanceMethods = false`. That is rare, and it is
/// detectable — see `hasReportedAppearance`.
@MainActor
final class ScreenProbe: UIViewController {

    enum Event {
        case willAppear
        case didAppear
        case willDisappear
        case didDisappear(ScreenDisappearReason)
    }

    private let route: RouteKey
    private(set) weak var receiver: ScreenLifecycleReceiver?

    /// The navigation controller the host belonged to while it was on screen.
    ///
    /// Captured on appearance because it is gone by the time we need it: once a screen
    /// is popped, `host.navigationController` is already nil, so there is nothing left
    /// to ask "was I removed from you?".
    private weak var owningNavigationController: UINavigationController?

    /// Whether the single "this screen went away" report has been made.
    ///
    /// Two paths can arrive at it and their order is not fixed: an unwind we initiated
    /// knows the screen is gone as soon as it asks UIKit, while the probe hears about it
    /// when the animation finishes — and containment teardown inverts that, reporting
    /// synchronously before the caller returns. Whoever claims it first wins; the flag
    /// lives on the probe because the probe outlives the record.
    private var didReportDisappearance = false

    /// Whether the observed screen is on screen right now.
    ///
    /// This is what decides who reports a removal. UIKit sends `viewDidDisappear` only
    /// to a screen that was actually visible, so a screen that is still up will get one
    /// — eventually, once its animation finishes — and it will carry the real reason.
    /// A screen that is already hidden (covered earlier, then removed) gets nothing
    /// more, and something else has to speak for it.
    ///
    /// Timing cannot answer this. Removals arrive both synchronously (containment
    /// teardown) and a third of a second later (an animated pop), so "has the probe
    /// spoken yet" is a race either way round; "will it speak at all" is not.
    private(set) var isHostVisible = false

    init(route: RouteKey, receiver: ScreenLifecycleReceiver) {
        self.route = route
        self.receiver = receiver
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        // Zero-sized and inert: this exists to observe, never to display or intercept.
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        self.view = view
    }

    /// Claims the right to report this screen's disappearance.
    /// - Returns: `true` for the first caller, `false` for every one after it.
    func claimDisappearanceReport() -> Bool {
        guard !didReportDisappearance else { return false }
        didReportDisappearance = true
        return true
    }

    /// The probe `receiver` has watching `viewController`, if it has one.
    ///
    /// Keyed by receiver because one view controller can be watched by more than one
    /// coordinator. A coordinator's `view()` can be dropped into an ordinary SwiftUI
    /// hierarchy — `VStack { Text("…"); ChildCoordinator().view() }` — in which case the
    /// child resolves to the same enclosing view controller as its parent. Returning the
    /// parent's probe there would leave the child hearing nothing at all.
    static func attached(to viewController: UIViewController, receiver: ScreenLifecycleReceiver) -> ScreenProbe? {
        viewController.children.lazy
            .compactMap { $0 as? ScreenProbe }
            .first { $0.receiver === receiver }
    }

    /// Attaches a probe to `host` for `receiver`, unless one is already there.
    @discardableResult
    static func attach(to host: UIViewController, route: RouteKey, receiver: ScreenLifecycleReceiver) -> ScreenProbe? {
        if let existing = attached(to: host, receiver: receiver) { return existing }
        let probe = ScreenProbe(route: route, receiver: receiver)
        host.addChild(probe)
        host.view.addSubview(probe.view)
        probe.didMove(toParent: host)
        probe.warnIfSilent(host: host, route: route)
        return probe
    }

    /// A container that turns off appearance forwarding makes this probe silent, and
    /// the app would otherwise have no way to notice: no lifecycle events would simply
    /// look like no navigation. Say so, rather than letting it be discovered later as
    /// "the callbacks don't fire sometimes".
    private func warnIfSilent(host: UIViewController, route: RouteKey) {
        #if DEBUG
        guard host.shouldAutomaticallyForwardAppearanceMethods else {
            assertionFailure("""
                Stinsen: \(type(of: host)) for route \(route) sets \
                shouldAutomaticallyForwardAppearanceMethods = false, so lifecycle \
                callbacks cannot be observed for it. Report them from the view \
                controller itself, or leave forwarding on.
                """)
            return
        }
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        report(.willAppear, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        owningNavigationController = parent?.navigationController
        isHostVisible = true
        report(.didAppear, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        report(.willDisappear, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isHostVisible = false
        guard let host = parent else { return }
        report(.didDisappear(reason(for: host)), animated: animated)
    }

    /// Why `host` stopped being visible.
    ///
    /// The flags come from the *host*, not the probe: the probe is only a child being
    /// carried along, while the host is the thing being popped, dismissed or covered.
    ///
    /// `isMovingFromParent` alone is not enough. After a completed **interactive** pop
    /// it reads `false` — the removal has already finished by the time
    /// `viewDidDisappear` runs — so a back swipe would be misreported as `.detached`
    /// (measured, not assumed). Asking the navigation controller whether it still holds
    /// the host covers both the programmatic and the interactive case, and answers the
    /// mirror-image question at the same time: a host the navigation controller *still*
    /// holds has not gone anywhere, something is merely on top of it.
    private func reason(for host: UIViewController) -> ScreenDisappearReason {
        if host.isBeingDismissed { return .dismissed }
        if host.isMovingFromParent { return .popped }

        if let nav = owningNavigationController {
            return nav.viewControllers.contains(host) ? .covered : .popped
        }
        // Presented and no longer presented by anyone: dismissed by some other path.
        if host.presentingViewController == nil, host.viewIfLoaded?.window == nil {
            return .dismissed
        }
        // Still in the window means something is simply on top of it, and it is very
        // much still on the stack.
        return host.viewIfLoaded?.window == nil ? .detached : .covered
    }

    private func report(_ event: Event, animated: Bool) {
        guard let host = parent else { return }
        receiver?.screenProbeDidObserve(event, probe: self, route: route, host: host, animated: animated)
    }
}
