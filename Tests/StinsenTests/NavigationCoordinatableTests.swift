//
//  NavigationCoordinatableTests.swift
//  StinsenTests
//
//  Comprehensive unit tests for NavigationCoordinatable public API
//

import XCTest
@testable import Stinsen
import SwiftUI

@MainActor
final class NavigationCoordinatableTests: XCTestCase {

    var coordinator: TestNavigationCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = TestNavigationCoordinator()
        coordinator.setupRoot()
    }

    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }

    // MARK: - Stack Management Tests

    func testInitialStackIsEmpty() {
        XCTAssertEqual(coordinator.stack.value.count, 0)
        XCTAssertEqual(coordinator.stack.currentRoute, -1)
    }

    func testRouteToViewAppendsToStack() {
        // When
        coordinator.route(to: \.detailView)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
    }

    func testRouteToCoordinatorAppendsToStack() {
        // When
        let childCoordinator = coordinator.route(to: \.childCoordinator)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertNotNil(childCoordinator)
    }

    func testRouteToOpaqueCoordinatorAppendsToStack() {
        // When — uses `some Coordinatable` return type (type-erased to AnyCoordinator)
        let child = coordinator.route(to: \.opaqueChild)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertNotNil(child)
        XCTAssertNotNil(child.parent)
    }

    func testRouteWithInputPassesCorrectValue() {
        // Given
        let testInput = "Test Value"

        // When
        coordinator.route(to: \.detailWithInput, testInput)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
        XCTAssertEqual(coordinator.stack.value.first?.input as? String, testInput)
    }

    func testPopToRootClearsStack() {
        // Given
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)
        XCTAssertEqual(coordinator.stack.value.count, 2)

        // When
        coordinator.popToRoot(nil)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 0)
    }

    func testPopToRootRunsItsCompletion() {
        // Given
        coordinator.route(to: \.detailView)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        // When
        var completed = false
        coordinator.popToRoot { completed = true }

        // Then — the completion runs when the rewind is done, rather than being filed
        // under an index for some later dismissal callback to look up.
        XCTAssertEqual(coordinator.stack.value.count, 0)
        XCTAssertTrue(completed)
    }

    // MARK: - Focus Tests

    func testFocusFirstFindsExistingRoute() throws {
        // Given
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)

        // When
        try coordinator.focusFirst(\.detailView)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 1)
    }

    func testFocusFirstThrowsWhenRouteNotFound() {
        // Given
        coordinator.route(to: \.secondDetailView)

        // Then
        XCTAssertThrowsError(try coordinator.focusFirst(\.detailView)) { error in
            XCTAssertTrue(error is FocusError)
        }
    }

    // MARK: - Root Management Tests

    func testRootSwitchesRootView() {
        // Given
        let root = coordinator.stack.root!
        let initialRoute = root.slots[root.activeSlotIndex].item.route

        // When
        coordinator.root(\.alternativeRoot)

        // Then
        XCTAssertNotEqual(root.slots[root.activeSlotIndex].item.route, initialRoute)
    }

    // MARK: - Animated Root Transition Tests

    func testAnimatedRootSwitchChangesActiveSlot() {
        // Given
        let initialSlot = coordinator.stack.root.activeSlotIndex

        // When — animation passed at call site
        coordinator.root(\.animatedRoot, animation: .easeInOut)

        // Then — animated transition → activeSlotIndex toggled
        XCTAssertNotEqual(coordinator.stack.root.activeSlotIndex, initialSlot)
    }

    func testAnimatedRootSwitchUpdatesZIndex() {
        // Given
        let initialZIndex = coordinator.stack.root.zIndex

        // When
        coordinator.root(\.animatedRoot, animation: .easeInOut)

        // Then — animated transition → zIndex +1
        XCTAssertEqual(coordinator.stack.root.zIndex, initialZIndex + 1)
    }

    func testNonAnimatedRootDoesNotChangeActiveSlot() {
        // When — no animation at call site
        coordinator.root(\.alternativeRoot)

        // Then — non-animated root → activeSlotIndex stays 0
        XCTAssertEqual(coordinator.stack.root.activeSlotIndex, 0)
    }

    func testNonAnimatedRootDoesNotChangeZIndex() {
        // Given
        let initialZIndex = coordinator.stack.root.zIndex

        // When
        coordinator.root(\.alternativeRoot)

        // Then
        XCTAssertEqual(coordinator.stack.root.zIndex, initialZIndex)
    }

    // MARK: - Parent-Child Relationship Tests

    func testChildCoordinatorHasCorrectParent() {
        // When
        let child = coordinator.route(to: \.childCoordinator)

        // Then
        XCTAssertNotNil(child.parent)
    }

    func testDismissChildRemovesFromStack() {
        // Given
        let child = coordinator.route(to: \.childCoordinator)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        // When
        coordinator.dismissChild(coordinator: child)

        // Then
        XCTAssertEqual(coordinator.stack.value.count, 0)
    }

    // MARK: - Stack State Tests

    func testCurrentRouteReturnsTopOfStack() {
        // Given
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)

        // Then
        XCTAssertNotEqual(coordinator.stack.currentRoute, -1)
    }

    // MARK: - Reconcile regressions (screens closed by something other than us)

    // These were `disappear(_ id:)` tests. The mechanism they covered is gone — an index
    // arriving from a per-level presentation controller, with the coordinator inferring
    // from it how much to remove — and it is the mechanism that caused the bug they were
    // written for (`7b1cac0`: dismissing the child also popped the parent).
    //
    // What has to stay true survives the rewrite unchanged: **a screen closed by a UI
    // gesture takes itself off the stack and nothing else.** Now that is answered by
    // asking UIKit rather than by arithmetic, so these drive a real navigation
    // controller and close screens behind the coordinator's back.

    /// Routes `count` screens onto a live navigation controller, one settled transition
    /// at a time.
    private func pushSettled(
        _ routes: [KeyPath<TestNavigationCoordinator, Stinsen.Transition<TestNavigationCoordinator, Presentation, Void, AnyView>>],
        on fixture: HostFixture
    ) {
        for route in routes {
            coordinator.route(to: route)
            fixture.settle()
        }
    }

    func testReconcile_afterExternalPopOfTheTopScreen_keepsTheOneBelow() {
        let fixture = HostFixture(coordinator: coordinator)
        pushSettled([\.detailView, \.secondDetailView], on: fixture)  // A, B
        XCTAssertEqual(coordinator.stack.value.count, 2)

        fixture.navigation.popViewController(animated: false)
        fixture.settle()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 1,
            "closing the child must not take the parent with it")
    }

    func testReconcile_afterExternalPopOfTheOnlyScreen_emptiesTheStack() {
        let fixture = HostFixture(coordinator: coordinator)
        pushSettled([\.detailView], on: fixture)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        fixture.navigation.popViewController(animated: false)
        fixture.settle()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 0)
    }

    /// A late callback for a screen we already removed used to pop again. Reconciling is
    /// idempotent by construction — it re-derives rather than stepping.
    func testReconcile_afterProgrammaticPop_isANoOp() {
        let fixture = HostFixture(coordinator: coordinator)
        pushSettled([\.detailView, \.secondDetailView], on: fixture)
        coordinator.popLast()
        fixture.settle()
        XCTAssertEqual(coordinator.stack.value.count, 1)

        coordinator.host.reconcile()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 1)
    }

    func testReconcile_afterExternalPop_removesOnlyWhatUIKitRemoved() {
        let fixture = HostFixture(coordinator: coordinator)
        pushSettled([\.detailView, \.secondDetailView, \.detailView], on: fixture)
        XCTAssertEqual(coordinator.stack.value.count, 3)

        fixture.navigation.popViewController(animated: false)
        fixture.settle()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 2)
    }

    /// Each screen's `onDismiss` runs once and only once, whichever side closed it.
    func testReconcile_firesOnDismissExactlyOnceForAnExternallyClosedScreen() {
        let fixture = HostFixture(coordinator: coordinator)
        var fired = 0
        coordinator.route(.push, to: Text("detail"), onDismiss: { fired += 1 })
        fixture.settle()

        fixture.navigation.popViewController(animated: false)
        fixture.settle()
        coordinator.host.reconcile()
        coordinator.host.reconcile()

        XCTAssertEqual(fired, 1)
    }

    // MARK: - The transition queue holds for every screen, not just the first

    /// Two screens routed before there is anywhere to put them, then a render.
    ///
    /// This is the deep-link shape: `route` twice while the coordinator has no anchor,
    /// so both are recorded as pending, and the first render drains them. Draining read
    /// "is a transition in flight" once on the way in and then presented every pending
    /// record in a loop — so both went to UIKit in the same run loop turn, which is
    /// precisely the thing UIKit discards.
    ///
    /// This pins the property rather than reproducing a past failure: before the queue
    /// was checked per screen, the old code was saved by `resolveContext()` refusing the
    /// second one for an unrelated reason (a just-pushed controller has no window yet).
    /// That is not a guarantee, and this test is what makes it one.
    func testDrainingPresentsOneScreenAtATime() {
        coordinator.route(.push, to: Text("first"))
        coordinator.route(.push, to: Text("second"))
        XCTAssertEqual(coordinator.stack.value.count, 2, "both recorded with nowhere to go yet")

        let fixture = HostFixture(coordinator: coordinator)

        XCTAssertEqual(fixture.navigation.viewControllers.count, 2,
            "only the first goes up: base + first")

        fixture.settle(until: { fixture.navigation.viewControllers.count == 3 })
        XCTAssertEqual(fixture.navigation.viewControllers.count, 3,
            "the second follows once the first transition finishes")
    }

    // MARK: - A presentation that arrives late

    /// A custom presentation that attaches its screen on a later run loop turn.
    ///
    /// Deferring is normal for a custom presentation — an animation to set up, a layout
    /// pass to wait for, a container to build — and `.presenting` is the state that exists
    /// to cover exactly that gap. It was being defeated one run loop turn after it was
    /// set: the built-in plumbing calls `onAppeared` a turn after `present` returns
    /// regardless of what the presentation did, that was taken as proof of arrival, and
    /// the next reconcile then found a `.live` record attached to nothing, deleted it and
    /// ran its `onDismiss`. The screen arrived afterwards with no record behind it —
    /// invisible to `popLast()`, invisible to `popToRoot()`, and already reported closed.
    func testDeferredCustomPresentationSurvivesUntilItAttaches() {
        let fixture = HostFixture(coordinator: coordinator)
        var dismissed = 0

        let deferredContainment = AnyPresentationType(
            make: { content, _ -> UIViewController in UIHostingController(rootView: content) },
            present: { parent, viewController in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    parent.addChild(viewController)
                    parent.view.addSubview(viewController.view)
                    viewController.didMove(toParent: parent)
                }
            },
            dismiss: { viewController in
                viewController.willMove(toParent: nil)
                viewController.view.removeFromSuperview()
                viewController.removeFromParent()
            }
        )

        coordinator.route(deferredContainment, to: Text("later"), onDismiss: { dismissed += 1 })

        // Long enough for the `onAppeared` hop to have happened, short enough that the
        // presentation has not attached yet. That is the window this is about, and a
        // reconcile lands in it whenever anything else navigates or reports lifecycle.
        fixture.settle(0.05)
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 1, "still ours while it is on its way")
        XCTAssertEqual(dismissed, 0, "nothing closed — nothing had opened yet")

        fixture.settle(until: { coordinator.stack.value.first?.state == .live })

        XCTAssertEqual(coordinator.stack.value.count, 1, "and it is up")
        XCTAssertTrue(coordinator.stack.value.first?.state == .live,
            "attached, so UIKit is the authority on it from here")
        XCTAssertEqual(dismissed, 0)
    }

    /// The other half: the exemption has to expire, and nothing may be relied on to end it.
    ///
    /// `.presenting` exempts a screen from UIKit's verdict because we cannot see it yet.
    /// A screen's own probe normally ends that by reporting its arrival — but a probe is
    /// silent inside a container that does not forward appearance callbacks, and attaching
    /// into a container of its own is an ordinary thing for a custom presentation to do.
    /// With nothing else looking, the exemption never expired: the screen was up, then
    /// closed by the app's own teardown, and the record sat in the stack through both
    /// because only `.live` records are ever checked against UIKit.
    func testCustomPresentationIntoASilentContainerIsStillReconciled() {
        let fixture = HostFixture(coordinator: coordinator)
        var dismissed = 0
        var presented: UIViewController?
        let container = NonForwardingContainer()

        let deferredSilentContainment = AnyPresentationType(
            make: { content, _ -> UIViewController in UIHostingController(rootView: content) },
            present: { parent, viewController in
                presented = viewController
                parent.addChild(container)
                parent.view.addSubview(container.view)
                container.didMove(toParent: parent)
                // Deferred as well as silent: attaching synchronously would be noticed by
                // the `onAppeared` hop, which is the path this one is meant to do without.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    container.addChild(viewController)
                    container.view.addSubview(viewController.view)
                    viewController.didMove(toParent: container)
                }
            },
            dismiss: { _ in }
        )

        coordinator.route(deferredSilentContainment, to: Text("overlay"), onDismiss: { dismissed += 1 })
        fixture.settle(until: { presented?.parent != nil })
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 1, "up, and nothing said so")
        XCTAssertTrue(coordinator.stack.value.first?.state == .live,
            "attached is attached, whether or not it was announced")

        // Somebody else's teardown: the app removing its own containment.
        presented?.willMove(toParent: nil)
        presented?.view.removeFromSuperview()
        presented?.removeFromParent()
        coordinator.host.reconcile()

        XCTAssertEqual(coordinator.stack.value.count, 0, "gone from UIKit is gone from the stack")
        XCTAssertEqual(dismissed, 1)
    }

    // MARK: - A presentation is torn down by whoever built it

    /// An app's own presentation that declares itself a `.push`.
    ///
    /// `kind` is a parameter of the initialiser, so it is a claim rather than a fact, and
    /// teardown used to believe it: a presentation declaring `.push` was folded into the
    /// batch `popToViewController` that closing a run of built-in screens uses, and its
    /// own `dismiss` closure — the reverse animation, the app's cleanup — never ran at all.
    /// Nothing warned, because from the outside the screen did go away.
    func testAppPresentationClaimingPushIsStillTornDownByItsOwnClosure() {
        let fixture = HostFixture(coordinator: coordinator)
        var dismissCalls = 0

        let containmentClaimingPush = AnyPresentationType(
            make: { content, _ -> UIViewController in UIHostingController(rootView: content) },
            present: { parent, viewController in
                parent.addChild(viewController)
                parent.view.addSubview(viewController.view)
                viewController.didMove(toParent: parent)
            },
            dismiss: { viewController in
                dismissCalls += 1
                viewController.willMove(toParent: nil)
                viewController.view.removeFromSuperview()
                viewController.removeFromParent()
            },
            kind: .push
        )

        coordinator.route(containmentClaimingPush, to: Text("overlay"))
        fixture.settle(until: { coordinator.stack.value.first?.state == .live })
        XCTAssertEqual(coordinator.stack.value.count, 1)

        coordinator.popLast()
        fixture.settle(until: { dismissCalls > 0 })

        XCTAssertEqual(dismissCalls, 1, "the app's teardown ran, whatever the kind claimed")
        XCTAssertEqual(coordinator.stack.value.count, 0)
    }

    // MARK: - A coordinator screen is resolved in the runtime presenting it

    /// A tab coordinator presented as a screen, by UIKit.
    ///
    /// The coordinator already answers "what am I as a view controller" — a real
    /// `UITabBarController`, which is the entire reason `viewController()` exists. Routing
    /// to it went through `view()` instead and hosted the SwiftUI `TabView`, so an app that
    /// had asked UIKit for everything else got a tab bar it could not configure or hook.
    func testRoutingToATabCoordinatorPresentsItsRealTabBarController() {
        let fixture = HostFixture(coordinator: coordinator)
        let tabs = ImperativeTabCoordinator()
        tabs.setupAllTabs()
        tabs.addTab(Text("one"), tabItem: { _ in Text("one") })

        coordinator.route(.modal, to: tabs)
        fixture.settle(until: { coordinator.stack.value.first?.viewController != nil })

        let presented = coordinator.stack.value.first?.viewController
        XCTAssertTrue(presented is UITabBarController,
            "presented by UIKit, so the coordinator's own UIKit representation is what goes "
            + "up — got \(presented.map { String(describing: type(of: $0)) } ?? "nothing"), "
            + "records: \(coordinator.stack.value.count)")
    }

    // MARK: - A screen arriving that we did not start

    /// Something else pushes onto the same navigation controller, then we route.
    ///
    /// The frontmost screen is then one of theirs, mid-arrival: no window yet, and
    /// invisible to `transitionCoordinator` for the rest of the run loop turn. That was
    /// read as "nothing is on screen — wait to be told", and nobody was going to tell us:
    /// the wake-ups are our own screens' probes and that screen has none. The record sat
    /// there until the user happened to navigate again.
    func testRoutingBehindSomeoneElsesPushStillArrives() {
        let fixture = HostFixture(coordinator: coordinator)

        let foreign = UIViewController()
        fixture.navigation.pushViewController(foreign, animated: true)
        coordinator.route(.push, to: Text("ours"))

        fixture.settle(until: { fixture.navigation.viewControllers.count == 3 })

        XCTAssertEqual(fixture.navigation.viewControllers.count, 3,
            "base, their screen, then ours")
        XCTAssertTrue(coordinator.stack.value.first?.state == .live,
            "and it is on screen, not still waiting to be told")
    }

    // MARK: - When an app-supplied screen's view gets loaded

    /// A view controller the app supplied, routed with `.push`.
    ///
    /// In plain UIKit `viewDidLoad` runs during the push, by which time the screen is in the
    /// navigation controller — which is why `navigationController?.…` in `viewDidLoad` is
    /// such a common line. Attaching the lifecycle probe touched `host.view` to add a
    /// subview, and touching it loads it: `viewDidLoad` ran a step early, before the screen
    /// had been pushed anywhere, and that line silently did nothing.
    ///
    /// **Known failure**, recorded rather than left to be discovered.
    ///
    /// The subview is not removable: measured with containment alone, and with the probe's
    /// view loaded but not inserted, UIKit sends the probe nothing — lifecycle stops and the
    /// transition queue loses the arrival it waits on. Attaching after the presentation
    /// instead is worse, because an unanimated push reports `viewDidAppear` synchronously
    /// and the arrival would be missed outright.
    ///
    /// So this stands until appearance comes from the navigation controller and presentation
    /// controller delegates instead of from an injected child. Flip the expectation when it
    /// does; the assertion below is already the right one.
    func testAppSuppliedScreenSeesItsNavigationControllerInViewDidLoad() {
        XCTExpectFailure("""
            attaching the lifecycle probe loads the screen's view before it is pushed, so \
            viewDidLoad runs without a navigation controller
            """)

        let fixture = HostFixture(coordinator: coordinator)
        let screen = NavigationAwareScreen()

        coordinator.route(.push, to: screen)
        fixture.settle(until: { screen.didLoad })

        XCTAssertTrue(screen.didLoad, "the screen was pushed, so its view was loaded")
        XCTAssertNotNil(screen.navigationControllerAtLoad,
            "viewDidLoad ran with the screen already in its navigation controller, as UIKit does it")
    }

    // MARK: - Deciding the root before anything has rendered

    /// Switching root on a coordinator that has never been rendered.
    ///
    /// Routing before the first render is explicitly supported — that is the deep-link case
    /// — and choosing a root at launch is the same shape of decision: check a token, pick
    /// the flow, then hand the coordinator to the window. This one trapped, on an
    /// implicitly-unwrapped `stack.root` that only the first render ever fills in. Nothing
    /// in the suite noticed because `setUp` renders the root by hand for every other test.
    func testRootBeforeFirstRenderDoesNotTrap() {
        let unrendered = TestNavigationCoordinator()

        unrendered.root(\.alternativeRoot)

        XCTAssertTrue(unrendered.hasRoot(\.alternativeRoot),
            "the switch took effect, rather than being lost or trapping")
    }

    // MARK: - Closing a coordinator closes what it was showing

    /// A tab coordinator shown as a screen, with a flow open inside one of its tabs.
    ///
    /// Closing the screen that holds a coordinator has to tell that coordinator, because
    /// UIKit removed its screens from a hierarchy it was not watching — that is what the
    /// teardown cascade is for, and it is the only thing that runs the per-screen
    /// `onDismiss` closures in this case.
    ///
    /// The cascade knew about navigation coordinators and about wrappers, and stopped dead
    /// at a tab coordinator: its tabs are coordinators with hosts and records of their own,
    /// and nothing reached them. Their screens stayed on the books for good — no
    /// `onDismiss`, and nothing left alive to ever reconcile them away.
    func testDismissingATabCoordinatorTearsDownTheFlowsInsideItsTabs() {
        var fired = 0
        let tabs = ImperativeTabCoordinator()
        tabs.setupAllTabs()
        let insideTab = TestChildCoordinator()
        tabs.addTab(insideTab, tabItem: { _ in Text("tab") })

        insideTab.route(.push, to: Text("deep"), onDismiss: { fired += 1 })
        XCTAssertEqual(insideTab.stack.value.count, 1)

        coordinator.route(.modal, to: tabs)
        coordinator.popLast()

        XCTAssertEqual(fired, 1, "the flow inside the tab was closed with the tab coordinator")
        XCTAssertEqual(insideTab.stack.value.count, 0)
    }

    // MARK: - Dismissing twice

    /// Asking a coordinator to dismiss itself twice.
    ///
    /// This is what a double tap on a "Done" button looks like, and it is not a
    /// programmer error. The refactor deleted `DismissingCoordinators`, the guard that
    /// used to swallow the second call, on the grounds that unwinding is idempotent —
    /// which it is. The question this test exists to answer is whether anything *else*
    /// on that path minds being asked twice.
    func testDismissCoordinator_twice_isNotAnError() {
        let child = coordinator.route(to: \.childCoordinator)
        let concrete = child.unwrap(TestChildCoordinator.self)
        XCTAssertNotNil(concrete)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        concrete?.dismissCoordinator()
        XCTAssertEqual(coordinator.stack.value.count, 0)

        var secondActionRan = false
        concrete?.dismissCoordinator { secondActionRan = true }

        XCTAssertEqual(coordinator.stack.value.count, 0,
            "dismissing an already-dismissed coordinator must stay a no-op")
        XCTAssertTrue(secondActionRan,
            "the completion still runs — what the caller wanted closed is closed")
    }

    // MARK: - Memory Management Tests

    func testWeakParentReference() {
        // Given
        var parent: TestNavigationCoordinator? = TestNavigationCoordinator()
        weak var weakParent = parent
        let child = parent!.route(to: \.childCoordinator)

        // When
        parent = nil

        // Then
        XCTAssertNil(weakParent)
        XCTAssertNil(child.parent)
    }

    func testCoordinatorDeallocation() {
        // Given
        weak var weakChild: AnyCoordinator?

        autoreleasepool {
            let parent = TestNavigationCoordinator()
            let child = parent.route(to: \.childCoordinator)
            weakChild = child
            XCTAssertNotNil(weakChild)

            // When
            parent.dismissChild(coordinator: child)
        }

        // Then - child should be deallocated
        XCTAssertNil(weakChild)
    }
}

// MARK: - Test Helpers

@MainActor
final class TestNavigationCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<TestNavigationCoordinator>(initial: \.mainView)

    @Root var mainView = makeMainView
    @Route(.push) var detailView = makeDetailView
    @Route(.push) var secondDetailView = makeSecondDetailView
    @Route(.push) var detailWithInput = makeDetailWithInput
    @Route(.push) var childCoordinator = makeChildCoordinator
    @Route(.push) var opaqueChild = makeOpaqueChild
    @Root var alternativeRoot = makeAlternativeRoot
    @Root var animatedRoot = makeAnimatedRoot

    func makeMainView() -> some View {
        Text("Main")
    }

    func makeDetailView() -> some View {
        Text("Detail")
    }

    func makeSecondDetailView() -> some View {
        Text("Second Detail")
    }

    func makeDetailWithInput(_ input: String) -> some View {
        Text("Detail: \(input)")
    }

    func makeChildCoordinator() -> TestChildCoordinator {
        TestChildCoordinator()
    }

    func makeOpaqueChild() -> some Coordinatable {
        TestChildCoordinator()
    }

    func makeAlternativeRoot() -> some View {
        Text("Alternative Root")
    }

    func makeAnimatedRoot() -> some View {
        Text("Animated Root")
    }
}

@MainActor
final class TestChildCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<TestChildCoordinator>(initial: \.childMain)

    @Root var childMain = makeChildMain

    func makeChildMain() -> some View {
        Text("Child Main")
    }
}

// MARK: - Back-to-back navigation

/// Two navigation calls in the same run loop tick.
///
/// This is what an app does when a completion handler routes straight after another
/// navigation, and UIKit discards the second one: `pushViewController` issued while a
/// push is still animating simply does nothing. It used to survive by accident — each
/// stack level had its own presentation controller that could not act until its view
/// controller had been introspected, which happened to be after the transition — and
/// that accident is gone, so the host has to serialise them deliberately.
@MainActor
final class BackToBackNavigationTests: XCTestCase {

    var coordinator: TestNavigationCoordinator!
    var fixture: HostFixture!

    override func setUp() {
        super.setUp()
        coordinator = TestNavigationCoordinator()
        coordinator.setupRoot()
        fixture = HostFixture(coordinator: coordinator)
    }

    override func tearDown() {
        fixture = nil
        coordinator = nil
        super.tearDown()
    }

    func testPushThenPush_bothScreensArrive() {
        coordinator.route(.push, to: Text("first"))
        coordinator.route(.push, to: Text("second"))

        fixture.settle(2)

        XCTAssertEqual(coordinator.stack.value.count, 2)
        XCTAssertEqual(coordinator.stack.value.compactMap(\.viewController).count, 2,
            "both screens must have reached UIKit")
        XCTAssertEqual(fixture.navigation.viewControllers.count, 3,
            "root plus two pushed screens")
    }

    // Presentations are not covered here, deliberately. In a bare XCTest host the
    // presentation animation never completes — the presented screen stays
    // `isBeingPresented` forever and never receives `viewDidAppear` — so a modal test
    // would be measuring the fixture rather than the coordinator. `PushThenPresent`,
    // `PresentThenPush` and `PresentThenPresent` are covered by the UI tests, which run
    // against a real app and a real run loop.
}

// MARK: - Test Helpers

/// Records what it could see of its surroundings at `viewDidLoad`.
@MainActor
private final class NavigationAwareScreen: UIViewController {
    var didLoad = false
    private(set) var navigationControllerAtLoad: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        didLoad = true
        navigationControllerAtLoad = navigationController
    }
}

/// A container that decides for itself which of its children is appearing — which means
/// none of them hear anything from UIKit, including a lifecycle probe.
///
/// Every UIKit container behaves this way (`UITabBarController`,
/// `UINavigationController`), so a custom presentation that builds containment of its own
/// is a realistic thing to be silent about.
@MainActor
private final class NonForwardingContainer: UIViewController {
    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
}
