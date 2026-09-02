import SwiftUI
import UIKit

/// Forwards a teardown cascade to whatever coordinator is wrapped.
///
/// A `ViewWrapperCoordinator` is not itself a navigation coordinator — it only decorates
/// one — so a cascade that stopped there would leave the wrapped coordinator's screens
/// believing they were still open.
@MainActor
protocol CoordinatorChildForwarding: AnyObject {
    var forwardedChild: any Coordinatable { get }
}

/// Owns one coordinator's screens and keeps them in step with UIKit.
///
/// One per coordinator, not one per screen. The trio it replaces — `PresentationHelper`,
/// `NavigationStackObserver` and `PresentationController` — existed once *per stack
/// level*, each holding a depth index, each re-deriving what the level above was doing.
/// The recursion was inherited from the SwiftUI implementation, where every level really
/// was a separate `View` value. Over UIKit there is nothing to recurse: view controllers
/// have identity, and `UINavigationController` already keeps them in order.
///
/// The division of labour is deliberate:
///
/// - `liveRecords()` **derives** and never mutates, so reads (`currentRoute`,
///   `isInStack`) cannot go stale and cannot have side effects.
/// - `reconcile()` **commits** that derivation and fires callbacks, and is only called
///   from mutating operations and lifecycle signals.
@MainActor
final class NavigationHost {

    /// The view controller this coordinator's screens hang off.
    ///
    /// Weak: UIKit owns it, and the host is owned by the coordinator. Not cached beyond
    /// this — `navigationController`, the presentation context and the screen chain are
    /// all re-read from it, because each of them can change without anyone telling us.
    private(set) weak var base: UIViewController?

    /// The coordinator these screens belong to. Used for lifecycle reporting only.
    weak var owner: AnyObject?

    /// Which route produced the coordinator's own root screen, so `base` can report
    /// lifecycle like any other screen.
    var rootRoute: RouteKey = .anonymous()

    private(set) var records: [RouteRecord] = []

    private var isReconciling = false

    /// Identifies the transition currently in flight, if any.
    ///
    /// Asking UIKit is not enough on its own: right after `pushViewController` returns,
    /// `transitionCoordinator` is still nil — the transition has been requested but not
    /// spun up — and a second push issued in that window is silently discarded. So the
    /// host tracks what it started rather than inferring it.
    ///
    /// A token rather than a flag, so a completion that arrives after its transition has
    /// already been superseded cannot release someone else's.
    private var transitionToken: UUID?

    /// The screen whose arrival ends the current transition.
    private weak var transitionScreen: UIViewController?

    /// What to run when the current transition finishes.
    ///
    /// Held here rather than threaded through the teardown because the teardown is not
    /// what knows when it is over — the screen going away is.
    private var transitionCompletion: (() -> Void)?

    /// How long to wait for a transition to report completion before assuming it never
    /// will. A jammed queue is worse than a rough transition: nothing would ever be
    /// presented again, silently.
    private static let transitionTimeout: TimeInterval = 3

    /// How long to wait before re-checking a context that was busy.
    private static let retryInterval: TimeInterval = 0.05

    private var retryScheduled = false
    private var retryDeadline: Date?

    init() {}

    // MARK: - Binding

    /// Points the host at the view controller its screens hang off.
    ///
    /// Idempotent: records live here, not on the view controller, so rebinding only
    /// swaps the anchor. Rebinding also drains anything recorded before there was
    /// anywhere to put it — routing during a deep link, before the first render, is a
    /// normal thing to do and discarding it would break exactly that case.
    func bind(base newBase: UIViewController) {
        guard base !== newBase else {
            presentPendingRecords()
            return
        }
        base = newBase
        // The coordinator's own root screen gets a probe like any other. Without one
        // it is the single screen whose lifecycle is invisible, and it is also the one
        // whose appearance tells a host with nowhere to present that it now has
        // somewhere.
        ScreenLifecycleAttachment.attach(to: newBase, route: rootRoute, receiver: self)
        presentPendingRecords()
    }

    // MARK: - Reading

    /// The records still backed by something on screen. Pure: no mutation, no callbacks.
    ///
    /// Uniform across presentation kinds on purpose. An earlier draft had built-in kinds
    /// checked by chain membership and custom ones by attachment, but "is this view
    /// controller still attached to anything" is correct for all of them — a popped one
    /// is attached to nothing, a covered one is still attached.
    func liveRecords() -> [RouteRecord] {
        guard base != nil else {
            // Nothing to ask. Records that never reached UIKit are still owed a
            // presentation; records that did have lost their anchor and are gone.
            return records.filter { $0.state != .live }
        }
        return records.filter { record in
            guard record.state == .live else { return true }
            guard let viewController = record.viewController else { return false }
            return viewController.isAttachedToHierarchy
        }
    }

    // MARK: - Reconciling

    /// Commits `liveRecords()` and reports what went away.
    ///
    /// Callbacks run **after** the records have been replaced, and deepest-first, so an
    /// `onDismiss` that navigates sees the stack it is navigating from rather than the
    /// one it is being removed from.
    func reconcile() {
        guard !isReconciling else { return }
        isReconciling = true
        defer { isReconciling = false }

        settlePresentingRecords()
        reattachLostProbes()

        let survivors = liveRecords()
        let survivorIDs = Set(survivors.map(\.id))
        let removed = records.filter { !survivorIDs.contains($0.id) }
        guard !removed.isEmpty else {
            presentPendingRecords()
            return
        }

        records = survivors
        // A screen that vanished without us asking left by some path we did not observe
        // — that is what `.detached` means.
        release(removed)
        // Something going away frees the context, so this is also a wake-up: a screen
        // recorded while a transition was in flight gets its turn here.
        presentPendingRecords()
    }

    /// Hands a custom presentation over to UIKit's authority once it has actually attached.
    ///
    /// `.presenting` is the state that says "we cannot see this screen yet, so do not
    /// judge it", and something has to end it. A probe reports the arrival for most
    /// screens, but a probe is silent inside a container that does not forward appearance
    /// callbacks — which is an ordinary thing for a custom presentation to attach into. So
    /// attachment is checked here as well, and a screen that is up is promoted whether or
    /// not anything announced it.
    ///
    /// Without this the exemption never expires: a custom screen closed by any path stays
    /// in `records` for good, because only `.live` records are subject to UIKit's verdict.
    private func settlePresentingRecords() {
        for index in records.indices where records[index].state == .presenting {
            guard records[index].viewController?.isAttachedToHierarchy == true else { continue }
            records[index].state = .live
        }
    }

    /// Puts back any probe that has gone missing from a screen still on the stack.
    ///
    /// A probe is a child view controller, and `children` belongs to the screen, not to
    /// us. Assigning `viewControllers` on a container replaces the children it manages
    /// and takes the probe with it; so does any app that rebuilds its own containment.
    /// Nothing announces that, and the failure is silent in the worst way — navigation
    /// keeps working, because liveness is derived from UIKit rather than from the probe,
    /// while lifecycle reporting quietly stops for that screen.
    ///
    /// This was not hypothetical: setting up the coordinator's own tab bar controller in
    /// `viewDidLoad` removed the probe that had been attached moments earlier. That one
    /// was fixed by reordering, which protects exactly one caller.
    private func reattachLostProbes() {
        for record in records where record.state == .live {
            guard let viewController = record.viewController,
                  viewController.isAttachedToHierarchy,
                  ScreenLifecycleAttachment.attached(to: viewController, receiver: self) == nil else { continue }

            #if DEBUG
            print("""
                Stinsen: the lifecycle probe for \(record.route) was removed from \
                \(type(of: viewController)) — something reassigned its children. \
                Reattaching.
                """)
            #endif
            ScreenLifecycleAttachment.attach(to: viewController, route: record.route, receiver: self)?
                .adoptCurrentState(of: viewController)
        }
    }

    /// Drops every record without touching UIKit.
    ///
    /// Called on the child when a parent removes the screen that held this coordinator.
    /// Without the cascade the child never learns its screens are gone: UIKit removed
    /// them, but it removed them from a hierarchy this host was not watching, so the
    /// per-screen `onDismiss` closures would simply never run.
    func teardown() {
        guard !records.isEmpty else { return }
        let removed = records
        records = []
        release(removed)
    }

    /// Reports and clears removed records, deepest first.
    ///
    /// `screenDidDisappear` fires exactly once per screen, and which of the two paths
    /// fires it depends on whether UIKit is still going to say something:
    ///
    /// - A screen that is **visible** is about to animate away, and its probe will
    ///   report the real reason — `.popped`, `.dismissed`, or whatever the app's own
    ///   custom teardown produced. Leave it to say so.
    /// - A screen that is **already hidden** had its `viewDidDisappear` when it was
    ///   covered, and UIKit sends no second one when it is finally removed. Nobody else
    ///   will speak for it, so report `.detached` here.
    ///
    /// That is the documented non-uniformity: the same logical event reads as `.popped`
    /// for the top screen and `.detached` for the ones underneath it. Anything doing
    /// "the screen closed" work has to handle both.
    ///
    /// Note this is decided on visibility rather than on who got here first. Removals
    /// arrive synchronously (containment teardown) *and* a third of a second later (an
    /// animated pop), so a race would resolve differently for the two and report the
    /// wrong reason for one of them.
    ///
    /// `onDismiss` is unconditional and synchronous either way — it says a screen was
    /// removed, which we already know.
    private func release(_ removed: [RouteRecord]) {
        for record in removed.reversed() {
            cascadeTeardown(record)
            if let viewController = record.viewController,
               let observation = ScreenLifecycleAttachment.attached(to: viewController, receiver: self),
               !observation.isHostVisible,
               observation.claimDisappearanceReport() {
                lifecycleAware?.screenDidDisappear(record.route, viewController: viewController, reason: .detached)
                // A screen that was already off-screen gets no `viewDidDisappear` when it
                // is finally removed, so the queue would otherwise sit here until the
                // watchdog. Nothing animated, so the transition is over.
                endTransitionOnDeparture(of: viewController)
            }
            record.onDismiss?()
            record.child?.parent = nil
        }
    }

    private func cascadeTeardown(_ record: RouteRecord) {
        guard let child = record.childObject else { return }
        Self.teardownHost(of: child)
    }

    /// Passes the cascade on to whatever coordinators this one is holding.
    ///
    /// Every kind of coordinator has to be answered for here, because the cascade is the
    /// only thing that reaches a coordinator whose screens were removed from a hierarchy it
    /// was not watching. A kind that is not handled does not fail loudly — it simply keeps
    /// its screens on the books, never runs their `onDismiss`, and is then left with
    /// nothing alive to ever reconcile them away.
    ///
    /// A tab coordinator was the missing kind. Its tabs are coordinators with hosts and
    /// records of their own, and unlike a wrapper it holds several — so the cascade fans
    /// out here rather than following a single child.
    static func teardownHost(of object: AnyObject) {
        let instance = coordinatorInstance(object: object)
        if let navigation = instance as? any NavigationCoordinatable {
            navigation.teardownHost()
        } else if let forwarding = instance as? CoordinatorChildForwarding {
            teardownHost(of: forwarding.forwardedChild)
        } else if let tabs = instance as? any TabCoordinatable {
            for child in tabs.tabbedCoordinators {
                teardownHost(of: child)
            }
        }
    }

    // MARK: - Presenting

    /// Records a screen and puts it on screen if there is anywhere to put it.
    ///
    /// The record is added **before** the presentation is attempted, so the synchronous
    /// meaning of `route(...)` is preserved: a `popLast()` or a `currentRoute` read on
    /// the very next line sees the screen that was just asked for.
    func append(_ record: RouteRecord) {
        records.append(record)
        presentPendingRecords()
    }

    private func presentPendingRecords() {
        guard base != nil else { return }
        // Index-based because presenting mutates the record in place, and because a
        // presentation can append further records re-entrantly.
        var index = 0
        while index < records.count {
            // Re-checked every iteration, not once on the way in. Presenting one screen
            // starts a transition and the rest of the queue has to wait for it; reading
            // the flag only on the way in meant a single drain could hand UIKit several
            // transitions in one run loop turn, which is what it discards.
            guard transitionToken == nil else { return }
            if records[index].state == .pending {
                // Stop at the first one that cannot go up yet. Skipping ahead would put
                // a later screen on before an earlier one, and the earlier one's context
                // is the later one's parent.
                guard present(at: index) else { return }
            }
            index += 1
        }
    }

    /// Tries again shortly, for as long as the only obstacle is a transition in flight.
    ///
    /// Not a substitute for the wake-up signals — it exists because those cannot cover
    /// everything. A transition nobody told us about (a back swipe, a sheet being
    /// dragged, the tail of a presentation UIKit still reports as in-flight after the
    /// screen has appeared) has no completion for us to ride. Retrying is bounded by the
    /// obstacle itself: it only reschedules while the context exists and is busy, so an
    /// off-screen coordinator does not spin.
    private func scheduleRetry() {
        let now = Date()
        let deadline = retryDeadline ?? now.addingTimeInterval(Self.transitionTimeout)
        retryDeadline = deadline
        guard now < deadline else {
            // A transition that has not finished in this long is not going to. Stop
            // polling and wait for a real signal instead; otherwise a presentation that
            // never completes turns into a permanent 20Hz timer.
            #if DEBUG
            print("""
                Stinsen: gave up waiting for a transition to finish after \
                \(Self.transitionTimeout)s. The screen recorded behind it will go up on \
                the next navigation or lifecycle event.
                """)
            #endif
            retryDeadline = nil
            return
        }
        guard !retryScheduled else { return }
        retryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self] in
            guard let self else { return }
            self.retryScheduled = false
            self.presentPendingRecords()
        }
    }

    @discardableResult
    private func present(at index: Int) -> Bool {
        let context: UIViewController
        switch resolveContext() {
        case .ready(let resolved):
            retryDeadline = nil
            context = resolved
        case .busy:
            scheduleRetry()
            return false
        case .unavailable:
            // Nothing on screen to present from. The anchor appearing is the wake-up —
            // that is how a route issued during a deep link, or into a tab that is not
            // selected, eventually goes up.
            return false
        }

        let record = records[index]

        warnIfPushIsImpossible(record, context: context)

        // A view controller the app supplied is presented as it is; only SwiftUI content
        // is built into one.
        let viewController = record.content.makeViewController(using: record.presentation)
        ScreenLifecycleAttachment.attach(to: viewController, route: record.route, receiver: self)

        records[index].viewController = viewController
        // The library's own presentations attach synchronously, so by the time `presented`
        // returns the screen is really there. An app's may not have — it can defer,
        // animate, or attach from a completion handler — so it stays `.presenting` until
        // something observes it arrive. Without that distinction the next reconcile would
        // find it attached to nothing and delete it mid-presentation.
        //
        // Asked as "did we build this", not as "what does it call itself": a presentation
        // that declares `.push` and then defers is exactly the case that would be marked
        // live while nothing was on screen.
        records[index].state = record.isBuiltIn ? .live : .presenting

        // Marked busy *before* control goes to the presentation, not after.
        //
        // A presentation is app code, and app code is allowed to navigate. Marking busy
        // afterwards left a window where anything the presentation did synchronously —
        // including routing again — ran while the queue still believed it was idle.
        //
        // Nothing user-visible was found to break through that window: `resolveContext()`
        // happened to refuse the second screen anyway, because a just-pushed view
        // controller is not in a window yet within the same call stack. That is the
        // accidental protection this whole refactor keeps replacing with a deliberate
        // one, so the ordering is fixed rather than relied upon.
        beginTransition(endingWhen: viewController)

        let id = record.id
        record.presentation.presented(
            parent: context,
            content: viewController,
            onAppeared: { [weak self] in self?.markLive(id) },
            // The built-in presentations no longer call this, and a custom one is not
            // required to. Disappearance is observed by the probe and re-derived by
            // `reconcile()`; a callback that may never arrive is not something to build
            // on. Wired to a reconcile anyway so a presentation that *does* call it is
            // not simply ignored.
            onDismissed: { [weak self] in self?.reconcile() }
        )
        return true
    }

    // MARK: - Serialising transitions

    private func beginTransition(endingWhen screen: UIViewController?, completion: (() -> Void)? = nil) {
        let token = UUID()
        transitionToken = token
        transitionScreen = screen
        transitionCompletion = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.transitionTimeout) { [weak self] in
            guard let self, self.transitionToken == token else { return }
            #if DEBUG
            print("""
                Stinsen: a transition never reported completion within \
                \(Self.transitionTimeout)s; releasing the queue so navigation can \
                continue. A custom presentation that never puts its view controller on \
                screen is the usual cause.
                """)
            #endif
            self.endTransition(token)
        }
    }

    private func endTransition(_ token: UUID) {
        guard transitionToken == token else { return }
        transitionToken = nil
        transitionScreen = nil

        // Before `presentPendingRecords`, not after: a completion that routes — "close
        // this, then open that" — records its screen here, and the pending pass that
        // follows is what puts it up. Running it afterwards would leave that screen
        // waiting for an unrelated event to come along and flush the queue.
        let completion = transitionCompletion
        transitionCompletion = nil
        completion?()

        presentPendingRecords()
    }

    /// Promotes a record once there is something on screen for it to be live *as*.
    ///
    /// A presentation's `onAppeared` is not evidence of that. The built-in ones hop a run
    /// loop turn and call it unconditionally, and a custom one may call it whenever it
    /// likes — so taking it at face value marked a screen live while it was attached to
    /// nothing, and the next reconcile duly deleted the record and ran its `onDismiss`
    /// while the presentation was still on its way. That defeated `.presenting` one run
    /// loop turn after it was set, which is the whole reason the state exists.
    ///
    /// The callback is therefore treated as a prompt to look, not as an answer. A
    /// presentation that attaches later is promoted by `settlePresentingRecords()` instead.
    private func markLive(_ id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        guard records[index].state != .live else { return }
        guard records[index].viewController?.isAttachedToHierarchy == true else { return }
        records[index].state = .live
    }

    /// A `.push` with no navigation controller in scope is a silent no-op, and an opaque
    /// closure gives no way to know a push was even intended. This is what `kind` buys.
    private func warnIfPushIsImpossible(_ record: RouteRecord, context: UIViewController) {
        #if DEBUG
        guard record.kind == .push, context.navigationController == nil else { return }
        assertionFailure("""
            Stinsen: route \(record.route) asked for a push, but \(type(of: context)) is \
            not inside a UINavigationController — nothing will happen. Wrap the \
            coordinator in a NavigationViewCoordinator, or present it modally instead.
            """)
        #endif
    }

    /// The view controller a new screen should be presented from: the frontmost screen
    /// this coordinator can see, or `nil` if now is not the moment.
    ///
    /// Re-derived per presentation rather than remembered. The remembered version was
    /// the reason a coordinator could present onto a view controller that had already
    /// gone away.
    ///
    /// **Returning `nil` defers rather than drops.** Two navigation calls in the same
    /// run loop tick — "dismiss this, then open that" — used to work by accident: each
    /// stack level had its own presentation controller that could not act until its view
    /// controller had been introspected, which happened to be after the previous
    /// transition. With one host that accident is gone, and UIKit simply discards a
    /// `pushViewController` issued mid-transition. So the wait is explicit now, and the
    /// screen that finishes arriving wakes the queue through its own probe.
    func presentationContext() -> UIViewController? {
        guard case .ready(let context) = resolveContext() else { return nil }
        return context
    }

    private enum ContextResult {
        /// Ready to present from.
        case ready(UIViewController)
        /// A transition is in flight. Try again in a moment.
        case busy
        /// Nothing is on screen. Wait to be told, rather than polling.
        case unavailable
    }

    private func resolveContext() -> ContextResult {
        guard let base else { return .unavailable }
        // The *frontmost* screen is the one that matters, not the anchor. Asking the
        // anchor goes wrong the moment anything is pushed over it: UIKit takes a covered
        // screen's view out of the window, so an anchor-based check would read "nowhere
        // to present" from the second navigation onwards — permanently.
        let context = ScreenChain.walk(from: base).last ?? base
        // Busy before on-screen, in that order: a screen in the middle of being
        // presented has no window *yet*, and calling that "unavailable" would stop the
        // retry that is the only thing waiting for it.
        if isTransitioning(context) { return .busy }
        // A screen arriving that we did not start — the app's own push, or another
        // coordinator's onto the same navigation controller — was expected to land here
        // and strand: `.unavailable` means "wait to be told", and the wake-ups are our own
        // screens' probes, which that screen does not have. It does not strand, because
        // `isTransitioning` above sees the transition through the shared navigation
        // controller and asks for a retry instead. Tried to construct a case where the
        // window check is reached with a foreign screen still on its way and could not, so
        // there is no extra branch here for one.
        guard context.viewIfLoaded?.window != nil else { return .unavailable }
        return .ready(context)
    }

    private func isTransitioning(_ context: UIViewController) -> Bool {
        // `transitionCoordinator` reads through to the nearest ancestor that is running
        // a transition, so this one question covers a push in flight, a presentation in
        // flight, and an interactive gesture that has not resolved.
        context.transitionCoordinator != nil
            || context.isBeingPresented
            || context.isBeingDismissed
            || context.presentedViewController?.isBeingDismissed == true
    }

    // MARK: - Unwinding

    /// Rewinds to the screen at `keepingFirst - 1`, or to `base` when that is 0.
    ///
    /// Positions appear here and nowhere else: they are resolved from identity by the
    /// caller, used inside this one operation, and discarded. That is the distinction
    /// the whole refactor turns on — an index computed and spent immediately is fine, an
    /// index stored and reused is what goes stale.
    ///
    /// **Push and presentation mix freely, and depth does not matter.** A stack is
    /// always "navigation run → presentation boundary → navigation run → …", and
    /// everything above a presentation boundary lives inside that modal's world. So
    /// dismissing the *lowest* boundary in range takes everything above it with it, and
    /// with no custom presentations involved the whole unwind is two UIKit calls
    /// regardless of depth:
    ///
    ///     base(nav1) → push A → push B → present C(nav2) → push D → present E
    ///     popToRoot: ① dismiss from C's presenter (C, D, E)  ② pop nav1 to base (A, B)
    ///
    /// The order is not a preference:
    ///
    /// 1. **Dismiss first, pop second.** A presented C whose presenter is B cannot
    ///    survive B being pulled out of the hierarchy first — that is the
    ///    "presenting view controller is not in the window hierarchy" family of breakage.
    /// 2. **Dismiss from the boundary's `presentingViewController`, not from `base`.**
    ///    If `base` is not the actual presenter, where `dismiss()` gets forwarded is
    ///    ambiguous.
    /// 3. **Ride the dismiss transition to pop.** Animating both overlaps them;
    ///    popping after the dismiss completes flashes the intermediate screen for a
    ///    frame. Popping *underneath* the outgoing modal shows one transition.
    /// - Note: assumes the caller has already reconciled — every entry point does,
    ///   because `count` has to be resolved against the same array this operates on.
    func unwind(keepingFirst count: Int, animated: Bool, completion: (() -> Void)? = nil) {
        let current = records
        guard count < current.count else {
            completion?()
            return
        }
        let keep = max(0, count)
        let removed = Array(current[keep...])

        records = Array(current[..<keep])

        let target = keep > 0 ? current[keep - 1].viewController : base
        // Closing animates too, so it holds the queue like any other transition. That is
        // what makes "pop, then open that" work: the second call records its screen
        // immediately and it goes up when the pop is done.
        //
        // The bottom-most screen is what the queue waits for. It is the one whose
        // dismissal drives the animation the user sees — the ones above it are inside it
        // and go with it — so its disappearance is when this is over.
        //
        // Only if it is on screen to begin with. A screen that is not in a window sends no
        // `viewDidDisappear` when it goes, so waiting for one holds the queue until the
        // watchdog and delivers the completion three seconds late — which is not "after it
        // closed", it is just late. Nothing is animating in that case, so there is nothing
        // to wait for.
        let departing = removed.first?.viewController
        guard departing?.viewIfLoaded?.window != nil else {
            performTeardown(of: removed, downTo: target, animated: animated)
            release(removed)
            completion?()
            presentPendingRecords()
            return
        }

        beginTransition(endingWhen: departing, completion: completion)
        performTeardown(of: removed, downTo: target, animated: animated)

        release(removed)
    }

    /// Takes the screens down, newest first, collapsing runs of built-in presentations
    /// into a single UIKit call.
    ///
    /// An app's own presentations are stepped through one at a time because their teardown
    /// is the app's own code — a reverse hero animation, its own cleanup — and skipping it
    /// is not an optimisation, it is a bug. With none of them in range the whole thing is
    /// one run, which is the common case.
    ///
    /// "Ours" is decided by `isBuiltIn`, never by the declared `kind`. Reading the
    /// declaration meant an app presentation that called itself `.push` was collapsed into
    /// a `popToViewController` and never saw its own `dismiss` closure at all.
    private func performTeardown(
        of removed: [RouteRecord],
        downTo target: UIViewController?,
        animated: Bool
    ) {
        guard base != nil else { return }

        var index = removed.count - 1
        while index >= 0 {
            if !removed[index].isBuiltIn {
                if let viewController = removed[index].viewController {
                    removed[index].presentation.dismissed(viewController: viewController)
                }
                index -= 1
                continue
            }

            var runStart = index
            while runStart >= 0 && removed[runStart].isBuiltIn {
                runStart -= 1
            }
            let anchor = runStart >= 0 ? removed[runStart].viewController : target
            collapseBuiltInRun(
                Array(removed[(runStart + 1)...index]),
                downTo: anchor,
                animated: animated
            )
            index = runStart
        }
    }

    /// One presentation dismiss plus one navigation pop, in that order, for a run of
    /// built-in screens.
    private func collapseBuiltInRun(
        _ run: [RouteRecord],
        downTo target: UIViewController?,
        animated: Bool
    ) {
        guard let anchor = target ?? base else { return }
        let anchorContainer = outermostContainer(of: anchor)

        // The lowest screen in range that lives outside the anchor's presentation world
        // is the boundary: everything above it is inside the same modal and goes with it.
        let boundary = run
            .compactMap(\.viewController)
            .map(outermostContainer(of:))
            .first { $0 !== anchorContainer }

        let pop = navigationPop(downTo: anchor)

        guard let boundary, let presenter = boundary.presentingViewController else {
            pop?(animated)
            return
        }

        presenter.dismiss(animated: animated)
        if let coordinator = presenter.transitionCoordinator {
            coordinator.animate(alongsideTransition: { _ in pop?(false) })
        } else {
            pop?(false)
        }
    }

    /// A closure that pops `anchor`'s navigation controller back to it, or `nil` when
    /// there is nothing above it to remove.
    private func navigationPop(downTo anchor: UIViewController) -> ((Bool) -> Void)? {
        guard let navigation = anchor.navigationController,
              let entry = anchor.navigationStackEntry,
              let index = navigation.viewControllers.firstIndex(of: entry),
              index < navigation.viewControllers.count - 1 else { return nil }
        return { animated in
            navigation.popToViewController(entry, animated: animated)
        }
    }

    /// The outermost container a view controller sits in — the thing that would have
    /// been presented, rather than the screen inside it.
    ///
    /// Comparing these is how a push is told from a presentation without asking the
    /// presentation what it is: two screens in the same container are in the same
    /// navigation world, and one in a different container got there across a
    /// presentation boundary.
    private func outermostContainer(of viewController: UIViewController) -> UIViewController {
        var current = viewController
        while let parent = current.parent {
            current = parent
        }
        return current
    }
}

// MARK: - Lifecycle

extension NavigationHost: ScreenLifecycleReceiver {

    private var lifecycleAware: (any CoordinatorLifecycleAware)? {
        owner as? any CoordinatorLifecycleAware
    }

    func screenLifecycleDidObserve(
        _ event: ScreenLifecycleEvent,
        observation: any ScreenLifecycleObservation,
        route: RouteKey,
        host viewController: UIViewController,
        animated: Bool
    ) {
        switch event {
        case .willAppear:
            lifecycleAware?.screenWillAppear(route, viewController: viewController, animated: animated)
        case .didAppear:
            markLive(viewController)
            // A screen arriving is the wake-up for anything recorded while it was on its
            // way — including the anchor itself, which is how routing before the first
            // render eventually renders.
            endTransitionOnArrival(of: viewController)
            presentPendingRecords()
            lifecycleAware?.screenDidAppear(route, viewController: viewController, animated: animated)
        case .willDisappear:
            lifecycleAware?.screenWillDisappear(route, viewController: viewController, animated: animated)
        case .didDisappear(let reason):
            noteDisappearance(
                observation: observation,
                of: viewController,
                route: route,
                reason: reason
            )
        }
    }

    private func markLive(_ viewController: UIViewController) {
        guard let index = records.firstIndex(where: { $0.viewController === viewController }) else { return }
        records[index].state = .live
    }

    /// Releases the queue now that the screen it was waiting for has arrived.
    ///
    /// Deliberately not tied to `transitionCoordinator`. Riding it works for a push but
    /// not for a presentation — a completion registered from `viewDidAppear` there is
    /// simply never called (measured), and the queue then sat until the watchdog. So the
    /// arrival itself is the signal, and the remaining slack — UIKit still reports the
    /// screen as `isBeingPresented` for a moment afterwards — is absorbed by the retry
    /// in `presentPendingRecords`, which is needed for externally driven transitions
    /// anyway.
    private func endTransitionOnArrival(of viewController: UIViewController) {
        guard viewController === transitionScreen, let token = transitionToken else { return }
        endTransition(token)
    }

    /// Releases the queue now that the screen it was waiting to see go has gone.
    ///
    /// The mirror of `endTransitionOnArrival`, and for the same reason. Closing was the
    /// one side of this that had no signal: `beginTransition(endingWhen: nil)` gave the
    /// queue nothing to wait for, so it fell back on the teardown reporting itself.
    /// The teardown cannot report itself — `performTeardown` hands the dismissal to a
    /// closure the app wrote and has no way to know what it did, let alone when it
    /// finished. It duly returned as soon as it had *asked* for the screen to go, which
    /// for an animated dismissal is the beginning of the transition rather than its end.
    ///
    /// So the disappearance is the signal, exactly as the arrival is on the other side.
    private func endTransitionOnDeparture(of viewController: UIViewController) {
        guard viewController === transitionScreen, let token = transitionToken else { return }
        endTransition(token)
    }

    private func noteDisappearance(
        observation: any ScreenLifecycleObservation,
        of viewController: UIViewController,
        route: RouteKey,
        reason: ScreenDisappearReason
    ) {
        // `.covered` means the screen is still on the stack — something is merely on top
        // of it — so it is not a disappearance to be claimed, and reconciling on it
        // would be pure churn.
        guard reason != .covered else {
            lifecycleAware?.screenDidDisappear(route, viewController: viewController, reason: reason)
            return
        }
        if observation.claimDisappearanceReport() {
            lifecycleAware?.screenDidDisappear(route, viewController: viewController, reason: reason)
        }
        endTransitionOnDeparture(of: viewController)
        reconcile()
    }
}
