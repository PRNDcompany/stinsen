//
//  NavigationUITests.swift
//  StinsenApp UI Tests
//
//  Real gestures and real UIKit transition timing. These cover what unit tests
//  structurally cannot: interactive pop, sheet swipe-down, and the dismiss→present
//  race, all of which depend on UIKit's actual animation lifecycle.
//
//  The app-side contract lives in `TestbedEnvironmentObjectScreen` — every
//  accessibility identifier used here is declared there.
//
//  Screens are numbered by the coordinator's factory and each carries a *unique*
//  identifier ("Screen-1", "Screen-2", ...). Assertions are existence-based on
//  purpose: XCUITest query order is not z-order, so "the last ScreenSerial match"
//  is not "the front screen" — a modal leaves the screen underneath in the tree and
//  that assumption silently inverts.
//

import XCTest

final class NavigationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting-authenticated"]

        // The same suite, against either entry point.
        //
        // Run with `TEST_RUNNER_STINSEN_UIKIT_ENTRY=1` and the app boots from a
        // `SceneDelegate` — `window.rootViewController = MainCoordinator().viewController()`
        // — instead of a SwiftUI `App`. Nothing else changes: same screens, same routes,
        // same assertions. That the tests do not need to know which one they are running
        // against is the claim, and running them twice is the only way to check it.
        if ProcessInfo.processInfo.environment["STINSEN_UIKIT_ENTRY"] == "1" {
            app.launchArguments.append("--uikit-entry")
        }

        app.launch()
        openTestbed()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Screen numbers are per process, not per coordinator — a child coordinator is a
    /// fresh instance and a per-instance counter would put a second "Screen-1" on
    /// screen. That makes the testbed root's own number depend on what the app built
    /// before it, so tests count from the root rather than from 1.
    private var rootSerial = 1

    /// The nth testbed screen, counting the testbed root as 1.
    private func screen(_ offset: Int) -> XCUIElement {
        app.staticTexts["Screen-\(rootSerial + offset - 1)"]
    }

    private func openTestbed() {
        let tab = app.tabBars.buttons["Testbed"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Testbed tab never appeared")
        tab.tap()

        // Whatever number the root got, everything after it is relative to that.
        guard poll(timeout: 10, until: { rawHighestVisibleSerial() != nil }),
              let root = rawHighestVisibleSerial() else {
            XCTFail("testbed root never appeared")
            return
        }
        rootSerial = root
        rootCoordinatorLabel = frontCoordinatorNumbers().first
    }

    /// The label of the coordinator that owns the testbed's root screen.
    private var rootCoordinatorLabel: String?

    /// The highest `Screen-N` present, by absolute number.
    private func rawHighestVisibleSerial(max: Int = 40) -> Int? {
        (1...max).reversed().first { app.staticTexts["Screen-\($0)"].exists }
    }

    /// Highest screen number currently present anywhere in the hierarchy.
    /// Screens are numbered monotonically, so "a higher one appeared" is the same
    /// question as "did the navigation actually happen".
    private func highestVisibleSerial(max: Int = 40) -> Int? {
        rawHighestVisibleSerial(max: max).map { $0 - rootSerial + 1 }
    }

    /// Polls `condition` until it holds or the deadline passes.
    /// Every wait in this file goes through here so they cannot drift apart.
    private func poll(timeout: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            usleep(200_000)
        } while Date() < deadline
        return false
    }

    private func waitForSerialAbove(_ base: Int, timeout: TimeInterval) -> Bool {
        poll(timeout: timeout) { (highestVisibleSerial() ?? 0) > base }
    }

    /// Samples the coordinator's own state and checks one of the labels it writes.
    ///
    /// Re-samples on every tick: the labels are only written when the sample button is
    /// tapped, so polling after a single sample would re-read a frozen value and report
    /// "never happened" for anything that happened late — exactly the timing these
    /// tests exist to measure.
    private func waitForSampledLabel(
        _ identifier: String,
        equals expected: String,
        timeout: TimeInterval
    ) -> Bool {
        poll(timeout: timeout) {
            tapButton("SampleStackState")
            return app.staticTexts.matching(identifier: identifier)
                .allElementsBoundByIndex
                .contains { $0.label == expected }
        }
    }

    /// What the coordinator believes about its own stack, compared against what UIKit
    /// actually shows.
    private func waitForStackState(_ expected: String, timeout: TimeInterval) -> Bool {
        waitForSampledLabel("StackState", equals: expected, timeout: timeout)
    }

    private func assertAppears(_ serial: Int, _ message: String,
                               timeout: TimeInterval = 5,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(screen(serial).waitForExistence(timeout: timeout),
                      message, file: file, line: line)
    }

    private func assertDisappears(_ serial: Int, _ message: String,
                                  timeout: TimeInterval = 5,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let gone = expectation(for: NSPredicate(format: "exists == false"),
                               evaluatedWith: screen(serial))
        let result = XCTWaiter().wait(for: [gone], timeout: timeout)
        XCTAssertEqual(result, .completed, message, file: file, line: line)
    }

    /// Taps the button on the *frontmost* screen.
    ///
    /// Every testbed screen carries the same button identifiers, so `app.buttons[id]`
    /// is ambiguous the moment a second screen exists — and the match it settles on is
    /// often the one underneath, which is not hittable. Only the front screen's
    /// controls are hittable, so that is the disambiguator.
    ///
    /// `ScrollView` also means a button can exist but sit below the fold, hence the
    /// scroll attempts before giving up.
    private func tapButton(_ identifier: String,
                           file: StaticString = #filePath, line: UInt = #line) {
        let query = app.buttons.matching(identifier: identifier)
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 5),
                      "button \(identifier) not found", file: file, line: line)

        // The testbed screen has grown long enough that a button can sit several
        // screenfuls down, so scroll generously before giving up.
        for attempt in 0...9 {
            if let hittable = query.allElementsBoundByIndex.first(where: { $0.isHittable }) {
                hittable.tap()
                return
            }
            if attempt < 9 { app.swipeUp() }
        }
        XCTFail("no hittable '\(identifier)' button on the front screen", file: file, line: line)
    }

    // MARK: - Back-to-back navigation (the class of defect this refactor targets)

    /// Two navigation operations issued in the same run loop tick — what an app does
    /// when a completion handler routes straight after a dismissal.
    ///
    /// Nothing serialises these today: each call mutates the stack and the observers
    /// act synchronously, so the second operation is issued while the first one's
    /// UIKit transition is still animating. Whether it survives depends on UIKit's
    /// tolerance for that specific pairing — which is how a screen silently stops
    /// appearing on one iOS version but not another.
    ///
    /// Every combo ends in an operation that must produce a new screen, so the pass
    /// condition is uniform: a screen with a higher serial must appear.
    ///
    /// Measured on iOS 18.5: `Present → Present` (the pairing originally suspected)
    /// currently survives, so this is a matrix rather than a single repro. The queue
    /// in stage 3 makes the guarantee hold for every pairing rather than leaving it
    /// to UIKit's discretion.
    func testBackToBackNavigation_secondOperationTakesEffect() {
        let combos = [
            "PopThenPush", "PopThenPresent",
            "PopToRootThenPush", "PopToRootThenPresent",
            "PushThenPush", "PushThenPresent",
            "PresentThenPush", "PresentThenPresent",
        ]

        var survived: [String] = []
        var dropped: [String] = []

        for combo in combos {
            // Relaunch rather than popToRoot between combos. L11 means popToRoot can
            // leave a modal on screen, and a half-reset state makes every later combo
            // report a failure it did not cause.
            app.terminate()
            app.launch()
            openTestbed()

            // Each combo starts from a screen it can pop from, so the "pop first"
            // pairings have something to remove.
            tapButton("ShowPush")
            guard let base = highestVisibleSerial() else {
                XCTFail("\(combo): could not establish a base screen")
                continue
            }

            tapButton("Combo-" + combo)

            if waitForSerialAbove(base, timeout: 4) {
                survived.append(combo)
            } else {
                dropped.append(combo)
            }
        }

        XCTAssertTrue(dropped.isEmpty,
            "these pairings dropped their second operation: \(dropped) (survived: \(survived))")
    }

    // MARK: - Gestures (only reachable through XCUITest)

    func testInteractiveBackSwipe_completed_returnsToPreviousScreen() {
        tapButton("ShowPush")
        assertAppears(2, "push should have appeared")

        // Full edge swipe left→right completes the pop.
        // A fast flick often does not register as an interactive pop at all, which
        // makes the assertion meaningless — drag slowly and hold at the end so UIKit
        // actually drives `interactivePopGestureRecognizer`.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)

        assertDisappears(2, "completed back swipe must pop the pushed screen")
        XCTAssertTrue(screen(1).exists, "root screen must be back")

        // The screen is gone. Does the coordinator know?
        //
        // This is the most common navigation action in any iOS app, and it is a
        // UIKit-initiated pop — exactly the category that
        // `testUIKitPop_bypassingTheCoordinator_keepsTheStackInSync` shows going
        // unnoticed. If the stack stays stale here, every later route/pop is computed
        // against a screen the user already dismissed.
        XCTAssertTrue(waitForStackState("empty", timeout: 5),
            "coordinator's stack must catch up with a back-swipe pop")
    }

    func testInteractiveBackSwipe_cancelled_staysOnScreen() {
        tapButton("ShowPush")
        assertAppears(2, "push should have appeared")

        // Short drag that does not pass the threshold — UIKit cancels the pop.
        //
        // Note this assertion is only meaningful because
        // `testInteractiveBackSwipe_completed_returnsToPreviousScreen` proves the same
        // gesture mechanism *can* pop. On its own, "screen 2 is still there" would also
        // pass if the gesture never registered at all.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)

        // Give the cancel animation time to settle, then confirm nothing was popped.
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(screen(2).exists, "cancelled back swipe must not pop")
    }

    func testSheetSwipeDown_dismissesTheModal() {
        tapButton("ShowModal")
        assertAppears(2, "modal should have appeared")

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.05, thenDragTo: end)

        assertDisappears(2, "swiping the sheet down must dismiss it")
    }

    // MARK: - Lifecycle

    /// Whatever the coordinator was last told, sampled now. Used in failure messages so
    /// a mismatch says what actually happened instead of only that it did not match.
    private func currentLifecycle() -> String {
        tapButton("SampleStackState")
        let labels = app.staticTexts.matching(identifier: "LifecycleState")
        return labels.allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }

    /// The most recent lifecycle event the coordinator was told about.
    private func waitForLifecycle(_ expected: String, timeout: TimeInterval) -> Bool {
        waitForSampledLabel("LifecycleState", equals: expected, timeout: timeout)
    }

    /// Whether `expected` appears anywhere in the log since it was last cleared.
    ///
    /// "The last event" is no longer the right question. The coordinator's root screen
    /// reports its own lifecycle now, so a closed screen is routinely followed by the
    /// one underneath reappearing — a back swipe genuinely ends on `didAppear`. Tests
    /// therefore clear the log, perform one action, and ask what that action reported.
    private func waitForLifecycleTrail(toContain expected: String, timeout: TimeInterval) -> Bool {
        poll(timeout: timeout) {
            tapButton("SampleStackState")
            return app.staticTexts.matching(identifier: "LifecycleTrail")
                .allElementsBoundByIndex
                .contains { $0.label.contains(expected) }
        }
    }

    /// The trail as currently sampled, for failure messages.
    private func currentLifecycleTrail() -> String {
        tapButton("SampleStackState")
        return app.staticTexts.matching(identifier: "LifecycleTrail")
            .allElementsBoundByIndex.map(\.label).joined(separator: " | ")
    }

    /// Does the probe actually fire, and does it say *why* a screen went away?
    ///
    /// Nothing before this could answer either question: dismissal was inferred from
    /// `deinit`, which arrives whenever ARC gets round to it and carries no reason.
    func testLifecycle_pushReportsAppearance() {
        tapButton("ShowPush")
        assertAppears(2, "push should have appeared")

        XCTAssertTrue(waitForLifecycle("didAppear", timeout: 5),
            "the probe must report the pushed screen appearing")
    }

    /// A screen that is merely covered by a modal is still on the stack — the reason
    /// has to distinguish that from being closed. Today the two are indistinguishable.
    func testLifecycle_modalReportsCoveredForTheScreenBeneath() {
        tapButton("ShowModal")
        assertAppears(2, "modal should have appeared")

        // Sampled on the modal, which reports its own appearance; the screen underneath
        // is the one that got covered.
        XCTAssertTrue(waitForLifecycle("didAppear", timeout: 5),
            "the probe must report the modal appearing")
    }

    /// Swiping a sheet away must be reported as a dismissal, not merely "it's gone".
    func testLifecycle_sheetSwipeDownReportsDismissed() {
        tapButton("ShowModal")
        assertAppears(2, "modal should have appeared")

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.05, thenDragTo: end)
        assertDisappears(2, "sheet must be dismissed")

        XCTAssertTrue(waitForLifecycle("didDisappear(dismissed)", timeout: 5),
            "a swiped-away sheet must be reported as .dismissed")
    }

    /// A completed back swipe must be reported as a pop, with that reason.
    func testLifecycle_backSwipeReportsPopped() {
        tapButton("ShowPush")
        assertAppears(2, "push should have appeared")
        // Clear first, so what follows is only what the swipe caused.
        tapButton("ResetLifecycleLog")

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        assertDisappears(2, "back swipe must pop")

        XCTAssertTrue(waitForLifecycleTrail(toContain: "didDisappear(popped)", timeout: 5),
            "a back-swiped screen must be reported as .popped, got: \(currentLifecycleTrail())")
    }

    /// Does the probe work for a **custom** presentation?
    ///
    /// The testbed's overlay attaches its screen by child containment instead of
    /// presenting it, which is the shape most likely to break reporting: such a view
    /// controller is never "being dismissed", and it is only "moving from parent" if
    /// the app's own teardown does proper containment removal.
    ///
    /// Built-in push and modal are already measured. This is the case that was assumed
    /// rather than checked.
    func testLifecycle_customContainmentPresentation_reportsAppearance() {
        tapButton("ShowCustomOverlay")
        assertAppears(2, "custom overlay should have appeared")

        XCTAssertTrue(waitForLifecycle("didAppear", timeout: 5),
            "the probe must see a containment-based custom presentation, got: \(currentLifecycle())")
    }

    func testLifecycle_customContainmentPresentation_reportsRemoval() {
        tapButton("ShowCustomOverlay")
        assertAppears(2, "custom overlay should have appeared")
        _ = waitForLifecycle("didAppear", timeout: 5)

        tapButton("ResetLifecycleLog")
        tapButton("PopLast")
        assertDisappears(2, "custom overlay must be removed")

        XCTAssertTrue(waitForLifecycleTrail(toContain: "didDisappear(popped)", timeout: 5),
            "containment removal must report a reason, got: \(currentLifecycleTrail())")
    }

    // MARK: - Staying in sync with UIKit

    /// Does the coordinator notice when something *outside* it closes a screen?
    ///
    /// This is the load-bearing question for the whole refactor. Anything can close a
    /// view controller — a UIKit parent, a system flow, third-party code, an app that
    /// kept its own reference. If the coordinator only learns about closures it
    /// initiated, its stack drifts from reality and every later pop targets the wrong
    /// screen.
    ///
    /// Today the only signal is `LifecycleObject.deinit`, so the answer depends on ARC:
    /// it arrives late, in no particular order, and never at all if anything is still
    /// retaining the view controller.
    func testUIKitDismiss_bypassingTheCoordinator_keepsTheStackInSync() {
        tapButton("ShowModal")
        assertAppears(2, "modal should have appeared")
        XCTAssertTrue(waitForStackState("nonempty", timeout: 3),
                      "precondition: coordinator should know it has a screen")

        tapButton("UIKitDismissBypass")
        assertDisappears(2, "UIKit dismiss must close the modal")

        // The screen is visually gone. Does the coordinator agree?
        // Sampled after a settle delay so a late ARC-driven callback still counts.
        XCTAssertTrue(waitForStackState("empty", timeout: 5),
            "coordinator's stack must catch up with a dismissal it did not initiate")
    }

    func testUIKitPop_bypassingTheCoordinator_keepsTheStackInSync() {
        tapButton("ShowPush")
        assertAppears(2, "push should have appeared")
        XCTAssertTrue(waitForStackState("nonempty", timeout: 3),
                      "precondition: coordinator should know it has a screen")

        tapButton("UIKitPopBypass")
        assertDisappears(2, "UIKit pop must remove the pushed screen")

        XCTAssertTrue(waitForStackState("empty", timeout: 5),
            "coordinator's stack must catch up with a pop it did not initiate")
    }

    // MARK: - Unwinding across a presentation boundary

    /// L11 (fixed) — `popToRoot()` used to clear the stack and leave the modal on screen.
    ///
    /// push → modal, then a single popToRoot. The unwind has to cross a presentation
    /// boundary rather than just walk a navigation stack. `popToIndex` could not: it
    /// emptied the coordinator's array while UIKit went on showing the modal, and every
    /// later operation then reasoned about a stack the user could not see.
    ///
    /// `unwind` dismisses from the lowest presentation boundary's presenter and pops the
    /// remaining navigation run underneath the outgoing modal, so this is one transition
    /// rather than two, with no intermediate screen flashing between them.
    func testMixedChain_popToRoot_returnsToRoot() {
        tapButton("BuildMixedChain")
        assertAppears(3, "expected root → push → modal")

        tapButton("PopToRoot")

        assertDisappears(3, "popToRoot must dismiss the modal")
        assertDisappears(2, "popToRoot must also pop the pushed screen")
        XCTAssertTrue(screen(1).exists, "root screen must be back")
    }

    // MARK: - Routing to a coordinator

    /// The coordinator number owning the frontmost screen, or nil if unreadable.
    ///
    /// Routing to a coordinator hands the flow to a different object with its own host,
    /// and nothing in the screen contents says so. Without this a "child coordinator"
    /// test would pass just as happily if the parent had pushed the screen itself.
    private func frontCoordinatorNumbers() -> [String] {
        app.staticTexts.matching(identifier: "CoordinatorID")
            .allElementsBoundByIndex.map(\.label)
    }

    /// Asserts some screen on the hierarchy belongs to a coordinator other than the one
    /// owning the testbed root. Which number it got depends on what the app built first,
    /// so the assertion is "someone else", not "number two".
    private func assertADifferentCoordinatorIsPresent(
        _ message: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let labels = frontCoordinatorNumbers()
        XCTAssertTrue(labels.contains { $0 != rootCoordinatorLabel },
                      "\(message) — saw \(labels), root is \(rootCoordinatorLabel ?? "unknown")",
                      file: file, line: line)
    }

    /// A pushed child coordinator, driving screens of its own.
    ///
    /// This shares one `UINavigationController` between parent and child, which is the
    /// supported direction of sharing — the parent's rewind is meant to take the child's
    /// screens with it. Nothing covered it: no test pressed this button, and the wrapper
    /// unit tests only check construction.
    func testPushCoordinator_childDrivesItsOwnScreens() {
        tapButton("ShowPushCoordinator")
        assertAppears(2, "the child coordinator's root screen should have been pushed")

        assertADifferentCoordinatorIsPresent("the pushed screen must belong to a new coordinator")

        // The child pushes into the navigation controller it shares with its parent.
        tapButton("ShowPush")
        assertAppears(3, "the child coordinator must be able to push")

        tapButton("PopLast")
        assertDisappears(3, "the child must be able to rewind its own screen")
        XCTAssertTrue(screen(2).exists, "the child's root screen must still be there")
    }

    /// `dismissCoordinator()` from inside the child: the child asks its parent to close
    /// it, and the parent has to recognise it despite the route having erased it to
    /// `AnyCoordinator` on the way in.
    func testPushCoordinator_dismissCoordinatorClosesTheChild() {
        tapButton("ShowPushCoordinator")
        assertAppears(2, "the child coordinator's root screen should have been pushed")

        tapButton("DismissCoordinator")

        assertDisappears(2, "dismissCoordinator() must close the child")
        XCTAssertTrue(screen(1).exists, "the parent's screen must be back")
        XCTAssertTrue(waitForStackState("empty", timeout: 5),
            "the parent must know the child is gone")
    }

    /// A child wrapped in `NavigationViewCoordinator` and presented modally.
    ///
    /// The wrapper is a coordinator that is not a `NavigationCoordinatable` — it only
    /// decorates one — so both the host binding and the teardown cascade have to pass
    /// through it. It also produces the shape that broke `PresentThenPush`: the
    /// `UINavigationController` ends up *inside* the presented hosting controller rather
    /// than above it.
    func testModalCoordinator_childPushesInsideItsOwnNavigationView() {
        tapButton("ShowModalCoordinator")
        assertAppears(2, "the wrapped coordinator's root screen should have been presented")

        assertADifferentCoordinatorIsPresent("the modal must belong to a new coordinator")

        // Must push into the modal's own navigation controller, not the app's.
        tapButton("ShowPush")
        assertAppears(3, "the wrapped coordinator must be able to push inside its modal")
        XCTAssertTrue(screen(1).exists,
            "the presenting screen stays in the hierarchy underneath")

        tapButton("PopLast")
        assertDisappears(3, "the wrapped coordinator must be able to rewind")
    }

    func testModalCoordinator_dismissCoordinatorClosesTheWrappedChild() {
        tapButton("ShowModalCoordinator")
        assertAppears(2, "the wrapped coordinator's root screen should have been presented")

        tapButton("DismissCoordinator")

        assertDisappears(2, "dismissCoordinator() must close the wrapped child")
        XCTAssertTrue(waitForStackState("empty", timeout: 5),
            "the parent must know the wrapped child is gone")
    }

    /// The parent rewinding past a child takes the child's screens with it.
    ///
    /// This is the cascade: UIKit removes the child's screens, but it removes them from
    /// a hierarchy the *child's* host is not watching, so without an explicit hand-off
    /// the child would go on believing they were open.
    func testPushCoordinator_parentPopToRootTakesTheChildsScreensWithIt() {
        tapButton("ShowPushCoordinator")
        assertAppears(2, "the child coordinator's root screen should have been pushed")
        tapButton("ShowPush")
        assertAppears(3, "the child pushed a screen of its own")

        // PopToRoot on the front screen is the *child's* — it only clears the child's own
        // stack. Reaching the parent's means going through the child's root screen.
        tapButton("PopToRoot")
        assertDisappears(3, "the child's own screen goes first")

        tapButton("DismissCoordinator")
        assertDisappears(2, "and then the child itself")
        XCTAssertTrue(screen(1).exists, "back to the parent's root")
    }

    // MARK: - Root switching

    /// Switching root has to take the open screens with it.
    ///
    /// A root switch is a flow-level change — signing out, finishing onboarding — and the
    /// screens the user had open belong to the flow that is ending. Leaving them up means
    /// the coordinator's records describe screens from a root that no longer exists, and
    /// every later pop is computed against them.
    func testRootSwitch_removesScreensFromTheOldRoot() {
        tapButton("ShowPush")
        assertAppears(2, "a screen is open when the root changes")

        tapButton("SwitchRoot")

        // In this order on purpose: a covered root is not in the accessibility tree at
        // all, so "did the root change" is unanswerable until the screen above it is
        // gone. The screen going away is also the thing being tested.
        assertDisappears(2, "switching root must take the pushed screen with it")
        XCTAssertTrue(app.staticTexts["AlternateRoot"].waitForExistence(timeout: 5),
                      "the new root must be what is left")
    }

    /// A root declared as a plain `UIViewController`.
    ///
    /// `@Root var uikitStart = makeUIKitStart` where the factory returns a view
    /// controller: the whole flow can now be UIKit from the root down, with no SwiftUI
    /// view anywhere in it.
    func testRootSwitch_toAUIKitRoot() {
        tapButton("SwitchToUIKitRoot")

        XCTAssertTrue(app.staticTexts["UIKitRoot"].waitForExistence(timeout: 5),
                      "a view controller must be able to be the root")
        assertDisappears(1, "the SwiftUI root it replaced must be gone")
    }

    // MARK: - UIKit tabs

    /// A tab coordinator hosted as a real `UITabBarController`.
    ///
    /// A UIKit app hosting a SwiftUI `TabView` gets a tab bar it cannot reach: no
    /// `UITabBarItem` to configure, no delegate to hook. The same `TabChild` drives both
    /// renderings, so `focusFirst`, `selectTab` and the re-tap callback are unchanged.
    func testUIKitTabs_switchTabs() {
        tapButton("ShowUIKitTabs")

        XCTAssertTrue(app.staticTexts["TabOneContent"].waitForExistence(timeout: 5),
                      "the tab bar controller should start on its first tab")

        let secondTab = app.tabBars.buttons["Two"]
        XCTAssertTrue(secondTab.waitForExistence(timeout: 5),
                      "the UITabBarItem declared by the route must be what the tab bar shows")
        secondTab.tap()

        XCTAssertTrue(app.staticTexts["TabTwoContent"].waitForExistence(timeout: 5),
                      "tapping a tab must switch the content")
    }

    // MARK: - UIKit screens

    /// A plain `UIViewController` routed to like any other screen.
    ///
    /// The transition engine has been UIKit's for a while, but every screen still had to
    /// be a SwiftUI view: `route(_:to:)` took a `View`, and the built-in presentations
    /// were typed to the hosting controller they built, so an app-supplied view
    /// controller could not get through at all.
    func testUIKitScreen_pushesAndPops() {
        tapButton("ShowUIKitScreen")
        assertAppears(2, "a UIKit screen must push like any other")
        XCTAssertTrue(app.staticTexts["ScreenKind"].exists,
                      "the pushed screen should be the UIKit one")

        tapButton("UIKitPopLast")
        assertDisappears(2, "popLast() must pop a UIKit screen")
        XCTAssertTrue(screen(1).exists, "back to the SwiftUI root")
    }

    func testUIKitScreen_presentsAsModal() {
        tapButton("ShowUIKitModal")
        assertAppears(2, "a UIKit screen must present like any other")

        tapButton("UIKitPopLast")
        assertDisappears(2, "popLast() must dismiss a UIKit modal")
    }

    /// A chain that alternates runtimes.
    ///
    /// A stack whose screens are all one kind proves much less: what matters is that the
    /// host reads the hierarchy the same way regardless of what built each screen, since
    /// its liveness check, its presentation context and its unwind all work on view
    /// controllers and never ask which runtime produced them.
    func testMixedRuntimeChain_unwindsInOneGo() {
        tapButton("ShowUIKitScreen")
        assertAppears(2, "UIKit screen")

        tapButton("UIKitPushSwiftUI")
        assertAppears(3, "SwiftUI screen pushed from a UIKit one")

        tapButton("ShowUIKitScreen")
        assertAppears(4, "UIKit screen pushed from a SwiftUI one")

        tapButton("UIKitPopToRoot")
        assertDisappears(4, "popToRoot must clear the whole mixed chain")
        assertDisappears(3, "…including the SwiftUI screen in the middle")
        assertDisappears(2, "…and the UIKit one at the bottom")
        XCTAssertTrue(screen(1).exists, "root screen must be back")
    }

    /// A UIKit screen reports its lifecycle like any other.
    ///
    /// Nothing was added to the view controller to make this work — the probe is a child
    /// view controller, and UIKit forwards appearance callbacks to children by default.
    func testUIKitScreen_reportsLifecycle() {
        tapButton("ResetLifecycleLog")
        tapButton("ShowUIKitScreen")
        assertAppears(2, "UIKit screen")

        // Sampling needs a SwiftUI testbed screen, so go back to one first.
        tapButton("UIKitPopLast")
        assertDisappears(2, "back to the SwiftUI root")

        XCTAssertTrue(waitForLifecycleTrail(toContain: "didDisappear(popped)", timeout: 5),
            "a popped UIKit screen must be reported as .popped, got: \(currentLifecycleTrail())")
    }

    // MARK: - A coordinator embedded as a child view

    /// `VStack { Text("…"); ChildCoordinator().view() }` — a coordinator dropped into an
    /// ordinary SwiftUI hierarchy rather than routed to.
    ///
    /// Two coordinators then sit behind the same enclosing view controller. Each needs
    /// its own anchor, its own records and its own lifecycle probe; sharing any of them
    /// means the embedded one is silently driven by, and reported as, its host.
    func testEmbeddedCoordinator_rendersAlongsideItsHost() {
        tapButton("ShowEmbeddedCoordinator")

        XCTAssertTrue(app.staticTexts["EmbeddedHost"].waitForExistence(timeout: 5),
                      "the embedding screen should have been pushed")
        // The embedding screen is a plain VStack, not a testbed screen, so it takes no
        // serial of its own — the next number belongs to the coordinator inside it.
        assertAppears(2, "the embedded coordinator's own screen should be inside it")
        assertADifferentCoordinatorIsPresent("the embedded screen must belong to its own coordinator")
    }

    /// The embedded coordinator drives its own navigation.
    ///
    /// A modal rather than a push on purpose: presenting resolves to the nearest
    /// presentation context, so it says something about *this* coordinator's host.
    /// Pushing would go into the navigation controller it shares with its host, which is
    /// the sibling-sharing case the library does not claim to disambiguate.
    func testEmbeddedCoordinator_presentsItsOwnScreens() {
        tapButton("ShowEmbeddedCoordinator")
        XCTAssertTrue(app.staticTexts["EmbeddedHost"].waitForExistence(timeout: 5),
                      "the embedding screen should have been pushed")
        assertAppears(2, "the embedded coordinator's own screen should be inside it")

        tapButton("ShowModal")
        assertAppears(3, "the embedded coordinator must be able to present")

        tapButton("PopLast")
        assertDisappears(3, "and to close what it presented")
    }

    /// The embedded coordinator hears about its own screens.
    ///
    /// This is what a shared probe cost: the host's probe was already attached to the
    /// shared view controller, so the embedded coordinator was handed it and received
    /// nothing at all.
    func testEmbeddedCoordinator_reportsItsOwnLifecycle() {
        tapButton("ShowEmbeddedCoordinator")
        assertAppears(2, "the embedded coordinator's own screen should be inside it")

        tapButton("ResetLifecycleLog")
        tapButton("ShowModal")
        assertAppears(3, "the embedded coordinator presented a screen")

        XCTAssertTrue(waitForLifecycleTrail(toContain: "didAppear", timeout: 5),
            "the embedded coordinator must be told about its own screen, got: \(currentLifecycleTrail())")
    }

    // MARK: - Re-entry

    /// L10 (fixed) — `popLast()` used to do nothing on the first pushed screen.
    ///
    /// The default dismiss handler decided between popping and dismissing with
    /// `navigationController.viewControllers.count > 2`. With a root plus one pushed
    /// screen the count is exactly 2, so it fell through to
    /// `viewController.dismiss(animated:)` — a no-op on a *pushed* view controller. The
    /// screen simply stayed.
    ///
    /// Fixed twice over: `unwind` pops through `popToViewController` and never consults
    /// that handler for a built-in presentation, and the threshold itself is now `> 1`
    /// for the app code that still calls the handler directly.
    func testPushPopPush_reEntersCleanly() {
        tapButton("ShowPush")
        assertAppears(2, "first push")

        tapButton("PopLast")
        assertDisappears(2, "popLast() must pop the first pushed screen")

        tapButton("ShowPush")
        assertAppears(3, "pushing again after a pop must work")
    }

    func testModalDismissModal_reEntersCleanly() {
        tapButton("ShowModal")
        assertAppears(2, "first modal")

        tapButton("PopLast")
        assertDisappears(2, "dismiss")

        tapButton("ShowModal")
        assertAppears(3, "presenting again after a dismiss must work")
    }
}
