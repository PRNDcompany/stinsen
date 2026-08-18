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

    /// Whether the screen is gone, as opposed to merely out of sight.
    ///
    /// Three of the four cases mean "closed", and which one you get depends on where the
    /// screen was: the top one reports `.popped` or `.dismissed`, while one that was
    /// already covered reports `.detached`, because UIKit had already sent its
    /// disappearance when it was covered and sends nothing more when it is finally
    /// removed. That distinction is real and worth having, but it should not be
    /// something every caller has to reconstruct — enumerating three cases to ask one
    /// question is how a fourth case, added later, silently stops being handled.
    public var isClosed: Bool { self != .covered }
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
/// ### What is guaranteed, and what is not
///
/// These are **observations**, not commitments. They are reported when UIKit says a
/// screen appeared or disappeared, so they inherit UIKit's silences: a screen inside a
/// container that does not forward appearance callbacks — every UIKit container turns
/// forwarding off — reports nothing at all, and neither does one whose view controller is
/// released before UIKit gets round to telling us.
///
/// `route(_:to:onDismiss:)` is the commitment. Its closure runs exactly once, whichever
/// path removed the screen, because the coordinator runs it itself when it drops the
/// record rather than waiting to be told. Use `onDismiss` for work that has to happen and
/// `screenDidDisappear` for work that follows from what the user did.
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

// MARK: - Observation

/// Receives lifecycle events from either an injected probe or a Stinsen-owned container.
@MainActor
protocol ScreenLifecycleReceiver: AnyObject {
    func screenLifecycleDidObserve(
        _ event: ScreenLifecycleEvent,
        observation: any ScreenLifecycleObservation,
        route: RouteKey,
        host: UIViewController,
        animated: Bool
    )
}

/// One receiver's claim on a screen's lifecycle.
///
/// An app-owned view controller is observed by a `ScreenProbe`. A container owned by
/// Stinsen reports its own appearance instead, because injecting a child probe would load
/// the container before UIKit has attached it to its navigation hierarchy. The host only
/// needs these pieces of state, so both mechanisms meet behind this protocol.
@MainActor
protocol ScreenLifecycleObservation: AnyObject {
    var isHostVisible: Bool { get }
    func adoptCurrentState(of host: UIViewController)
    func claimDisappearanceReport() -> Bool
}

@MainActor
enum ScreenLifecycleEvent {
    case willAppear
    case didAppear
    case willDisappear
    case didDisappear(ScreenDisappearReason)
}

/// Adopted by Stinsen-owned containers that can report appearance without a child probe.
@MainActor
protocol ScreenLifecycleReporting: AnyObject {
    var screenLifecycleReporter: ScreenLifecycleReporter { get }
}

/// Chooses the least invasive observation mechanism a screen supports.
///
/// Library containers report directly. Everything else remains observable without
/// subclassing or swizzling through the existing child-controller probe.
@MainActor
enum ScreenLifecycleAttachment {
    static func attached(
        to viewController: UIViewController,
        receiver: ScreenLifecycleReceiver
    ) -> (any ScreenLifecycleObservation)? {
        if let reporting = viewController as? any ScreenLifecycleReporting {
            return reporting.screenLifecycleReporter.observation(for: receiver)
        }
        return ScreenProbe.attached(to: viewController, receiver: receiver)
    }

    @discardableResult
    static func attach(
        to viewController: UIViewController,
        route: RouteKey,
        receiver: ScreenLifecycleReceiver
    ) -> (any ScreenLifecycleObservation)? {
        if let reporting = viewController as? any ScreenLifecycleReporting {
            return reporting.screenLifecycleReporter.attach(
                to: viewController,
                route: route,
                receiver: receiver
            )
        }
        return ScreenProbe.attach(to: viewController, route: route, receiver: receiver)
    }
}

/// Appearance fan-out for a Stinsen-owned container.
///
/// There can be more than one observer: the coordinator represented by the container
/// watches its root, while the parent coordinator watches the container as one of its
/// routed screens. Each gets an independent disappearance claim.
@MainActor
final class ScreenLifecycleReporter {
    private var observations: [DirectScreenLifecycleObservation] = []

    private weak var owningNavigationController: UINavigationController?
    private weak var owningNavigationEntry: UIViewController?
    private weak var owningHostContainer: UIViewController?

    func observation(for receiver: ScreenLifecycleReceiver) -> (any ScreenLifecycleObservation)? {
        removeDeadObservations()
        return observations.first { $0.receiver === receiver }
    }

    func attach(
        to host: UIViewController,
        route: RouteKey,
        receiver: ScreenLifecycleReceiver
    ) -> any ScreenLifecycleObservation {
        if let existing = observation(for: receiver) {
            return existing
        }
        let observation = DirectScreenLifecycleObservation(route: route, receiver: receiver)
        observation.adoptCurrentState(of: host)
        observations.append(observation)
        return observation
    }

    func viewWillAppear(_ host: UIViewController, animated: Bool) {
        report(.willAppear, from: host, animated: animated)
    }

    func viewDidAppear(_ host: UIViewController, animated: Bool) {
        owningNavigationController = host.navigationController
        owningNavigationEntry = host.navigationStackEntry
        owningHostContainer = host.parent
        report(.didAppear, from: host, animated: animated)
    }

    func viewWillDisappear(_ host: UIViewController, animated: Bool) {
        report(.willDisappear, from: host, animated: animated)
    }

    func viewDidDisappear(_ host: UIViewController, animated: Bool) {
        report(.didDisappear(reason(for: host)), from: host, animated: animated)
    }

    private func report(
        _ event: ScreenLifecycleEvent,
        from host: UIViewController,
        animated: Bool
    ) {
        removeDeadObservations()
        observations.forEach { $0.report(event, host: host, animated: animated) }
    }

    private func removeDeadObservations() {
        observations.removeAll { $0.receiver == nil }
    }

    /// Same measured rules as `ScreenProbe`, now applied to the reporting controller.
    private func reason(for host: UIViewController) -> ScreenDisappearReason {
        if host.isBeingDismissed { return .dismissed }
        if host.isMovingFromParent { return .popped }

        if let container = owningHostContainer, host.parent !== container {
            return .popped
        }
        if let navigation = owningNavigationController, let entry = owningNavigationEntry {
            return navigation.viewControllers.contains { $0 === entry } ? .covered : .popped
        }
        if host.presentingViewController == nil, host.viewIfLoaded?.window == nil {
            return .dismissed
        }
        return host.viewIfLoaded?.window == nil ? .detached : .covered
    }
}

@MainActor
private final class DirectScreenLifecycleObservation: ScreenLifecycleObservation {
    let route: RouteKey
    private(set) weak var receiver: (any ScreenLifecycleReceiver)?
    private(set) var isHostVisible = false
    private var didReportDisappearance = false

    init(route: RouteKey, receiver: ScreenLifecycleReceiver) {
        self.route = route
        self.receiver = receiver
    }

    func adoptCurrentState(of host: UIViewController) {
        isHostVisible = host.viewIfLoaded?.window != nil
    }

    func claimDisappearanceReport() -> Bool {
        guard !didReportDisappearance else { return false }
        didReportDisappearance = true
        return true
    }

    func report(_ event: ScreenLifecycleEvent, host: UIViewController, animated: Bool) {
        switch event {
        case .didAppear:
            isHostVisible = true
        case .didDisappear:
            isHostVisible = false
        case .willAppear, .willDisappear:
            break
        }
        receiver?.screenLifecycleDidObserve(
            event,
            observation: self,
            route: route,
            host: host,
            animated: animated
        )
    }
}

// MARK: - Probe

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
final class ScreenProbe: UIViewController, ScreenLifecycleObservation {

    private let route: RouteKey
    private(set) weak var receiver: ScreenLifecycleReceiver?

    /// The navigation controller the host belonged to while it was on screen.
    ///
    /// Captured on appearance because it is gone by the time we need it: once a screen
    /// is popped, `host.navigationController` is already nil, so there is nothing left
    /// to ask "was I removed from you?".
    private weak var owningNavigationController: UINavigationController?

    /// The ancestor the navigation controller actually holds.
    ///
    /// Not the same object as the host: a host is often nested — the coordinator's own
    /// anchor sits inside a hosting controller — so asking whether the navigation
    /// controller still contains *the host* is asking about something that was never in
    /// it. That read every push as a pop of the screen underneath, which is a screen
    /// that had not gone anywhere.
    private weak var owningNavigationEntry: UIViewController?

    /// What was holding the host while it was on screen.
    ///
    /// The one question that separates "removed" from "covered" for every kind of
    /// screen: a popped screen loses its navigation controller, a screen taken out of a
    /// container by the app's own teardown loses that container, and a covered screen
    /// loses neither. Asking the navigation controller alone gets the containment case
    /// wrong — an overlay's navigation entry is the screen *underneath* it, which is
    /// still very much there.
    private weak var owningHostContainer: UIViewController?

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

    /// Tells a freshly attached probe what it missed.
    ///
    /// A probe learns everything from the callbacks it receives, so one attached to a
    /// screen that is *already* on screen has seen nothing: it does not know the screen
    /// is visible, and it does not know which navigation controller holds it — both of
    /// which are recorded on appearance and both of which decide how a later removal is
    /// reported. Without this a re-attached probe called a pop a `.dismissed`.
    ///
    /// Only ever called for a screen that is on screen now, which is why reading the
    /// state directly is equivalent to having observed it.
    func adoptCurrentState(of host: UIViewController) {
        isHostVisible = host.viewIfLoaded?.window != nil
        owningNavigationController = host.navigationController
        owningNavigationEntry = host.navigationStackEntry
        owningHostContainer = host.parent
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
    ///
    /// ### The subview is load-bearing, and it costs something
    ///
    /// `addSubview` looks like ceremony next to `addChild` — appearance forwarding is
    /// described in terms of child view *controllers* — but it is not. Measured both ways:
    /// with containment alone, and with the probe's own view loaded but not inserted, UIKit
    /// sends the probe nothing at all. Lifecycle stops, and with it the queue's wake-up,
    /// which is `viewDidAppear` on the screen that just arrived. Do not remove it.
    ///
    /// The cost is that `host.view` is lazy, so this loads it. For a view controller the app
    /// supplied, that runs its `viewDidLoad` a step earlier than UIKit would have — before
    /// the screen has been pushed — so a `navigationController?.…` line there sees nil and
    /// silently does nothing. `testAppSuppliedScreenSeesItsNavigationControllerInViewDidLoad`
    /// records that as a known failure rather than leaving it to be discovered.
    ///
    /// Attaching after the presentation instead would trade it for a worse loss: an
    /// unanimated push sends `viewDidAppear` synchronously, so the arrival that releases the
    /// queue would be missed outright. The real answer is to stop inferring appearance from
    /// an injected child and take it from the navigation controller and presentation
    /// controller delegates, which is a change to how observation works rather than to when
    /// this line runs.
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

    /// A container that turns off appearance forwarding makes this probe silent, and the
    /// app would otherwise have no way to notice: no lifecycle events simply looks like
    /// no navigation. Say so, rather than letting it be discovered later as "the
    /// callbacks don't fire sometimes".
    ///
    /// A log rather than an assertion, because this is not always a mistake. Every UIKit
    /// container — `UITabBarController`, `UINavigationController` — turns forwarding off
    /// and decides for itself which child is appearing, which is correct behaviour and
    /// exactly what a coordinator's own tab bar controller does. Trapping on it killed
    /// the example app the first time a tab coordinator was presented as a screen.
    ///
    /// A container that wants to be observed can forward to its probes explicitly with
    /// `beginAppearanceTransition` / `endAppearanceTransition`.
    private func warnIfSilent(host: UIViewController, route: RouteKey) {
        #if DEBUG
        guard !host.shouldAutomaticallyForwardAppearanceMethods else { return }
        print("""
            Stinsen: \(type(of: host)) for route \(route) does not forward appearance \
            callbacks to its children, so lifecycle cannot be observed for it. Expected \
            for a container view controller; if it is not one, leave forwarding on or \
            report appearance from the view controller itself.
            """)
        #endif
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        report(.willAppear, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        owningNavigationController = parent?.navigationController
        owningNavigationEntry = parent?.navigationStackEntry
        owningHostContainer = parent?.parent
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

        // Taken out of whatever was holding it — popped off a navigation controller, or
        // removed from a container by the app's own teardown. Both are removals; a
        // covered screen is still held by the same thing it always was.
        if let container = owningHostContainer, host.parent !== container {
            return .popped
        }

        if let nav = owningNavigationController, let entry = owningNavigationEntry {
            return nav.viewControllers.contains { $0 === entry } ? .covered : .popped
        }
        // Presented and no longer presented by anyone: dismissed by some other path.
        if host.presentingViewController == nil, host.viewIfLoaded?.window == nil {
            return .dismissed
        }
        // Still in the window means something is simply on top of it, and it is very
        // much still on the stack.
        return host.viewIfLoaded?.window == nil ? .detached : .covered
    }

    private func report(_ event: ScreenLifecycleEvent, animated: Bool) {
        guard let host = parent else { return }
        receiver?.screenLifecycleDidObserve(
            event,
            observation: self,
            route: route,
            host: host,
            animated: animated
        )
    }
}
