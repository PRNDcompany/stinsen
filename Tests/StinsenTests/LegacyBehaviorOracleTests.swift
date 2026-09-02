//
//  LegacyBehaviorOracleTests.swift
//  StinsenTests
//
//  Behavior oracle for the UIKit-owned-stack refactor.
//
//  Two kinds of tests live here:
//
//  1. PINS — assert behaviour that MUST survive the refactor. If one of these goes red,
//     the refactor changed something it was not supposed to change.
//
//  2. FIXED DEFECTS — each was written first as the *desired* behaviour under
//     `XCTExpectFailure`, so it failed (and passed the suite) while the defect stood.
//     Fixing one turned it into an "unexpected pass" and went red, forcing whoever fixed
//     it to remove the marker deliberately. A defect could not be silently fixed, and now
//     cannot be silently reintroduced.
//
//  All four are fixed and every marker is gone — L1 (consecutive same route dropped),
//  L3 (routing from a dismissal action truncated), L4 (dismissing an unknown coordinator
//  closed an unrelated screen), L8 (popLast on an empty stack stranded its closure).
//  Defect IDs match the plan document.
//

import XCTest
@testable import Stinsen
import SwiftUI

@MainActor
final class LegacyBehaviorOracleTests: XCTestCase {

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

    // MARK: - PINS (must survive the refactor)

    /// Non-consecutive repeats of the same route are legal and produce distinct entries.
    /// The refactor must keep this true — it is the weaker half of the A→A story.
    func testPin_nonConsecutiveSameRoute_producesDistinctEntries() {
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)
        coordinator.route(to: \.detailView)

        XCTAssertEqual(coordinator.stack.value.count, 3,
            "A→B→A must produce three entries")
    }

    /// A pop that spans several levels removes everything above the target in one call.
    func testPin_multiLevelPop_removesEverythingAboveTarget() {
        coordinator.route(to: \.detailView)
        coordinator.route(to: \.secondDetailView)
        coordinator.route(to: \.detailWithInput, "x")
        XCTAssertEqual(coordinator.stack.value.count, 3)

        try? coordinator.focusFirst(\.detailView)

        XCTAssertEqual(coordinator.stack.value.count, 1,
            "rewinding must keep exactly the target and drop the two above it")
    }

    /// `input` is carried on the entry and is what `focusFirst`'s comparator sees.
    func testPin_inputIsCarriedOnTheEntry() {
        coordinator.route(to: \.detailWithInput, "alpha")
        coordinator.route(to: \.secondDetailView)
        coordinator.route(to: \.detailWithInput, "beta")

        let inputs = coordinator.stack.value.compactMap { $0.input as? String }
        XCTAssertEqual(inputs, ["alpha", "beta"])
    }

    // MARK: - FIXED DEFECTS (markers removed deliberately, as the oracle demands)

    /// L1 — consecutive entry into the same route used to be silently dropped.
    ///
    /// `CoordinatorStack.push` compared `lastItem.keyPath == item.keyPath`, and `keyPath`
    /// was `route.hashValue` — it never looked at `input`. So the canonical commerce flow
    /// (product detail → related product → product detail) lost the second push with no
    /// error and no log.
    ///
    /// Fixed by removing the dedupe outright. UIKit does not deduplicate pushes either,
    /// and the double-tap protection this was standing in for belongs to the app —
    /// swallowing a legitimate drill-down to provide it is a worse trade than not
    /// providing it. The serial transition queue takes over the double-tap case.
    func testFixed_L1_consecutiveSameRouteWithDifferentInput_pushesBothScreens() {
        coordinator.route(to: \.detailWithInput, "product-1")
        coordinator.route(to: \.detailWithInput, "product-2")

        XCTAssertEqual(coordinator.stack.value.count, 2,
            "Drilling from product-1 into product-2 must push a second screen")
        XCTAssertEqual(coordinator.stack.value.map { $0.input as? String },
                       ["product-1", "product-2"])
    }

    /// L3 — a dismissal action used to run *before* the pop, so anything it routed to was
    /// truncated by the very next statement. "when this closes, open that" silently did
    /// nothing.
    ///
    /// Fixed by attaching `onDismiss` to the screen being opened and running it after the
    /// records have already been replaced — there is no later statement left to undo it.
    func testFixed_L3_routeFromDismissalAction_survives() {
        // stack = [A, B]; B carries "when I close, open C".
        coordinator.route(to: \.detailView)
        var actionDidRun = false
        coordinator.route(to: \.secondDetailView, onDismiss: { [weak coordinator] in
            actionDidRun = true
            coordinator?.route(to: \.detailWithInput, "opened-from-onDismiss")
        })

        coordinator.popLast()

        XCTAssertTrue(actionDidRun, "precondition: the dismissal action must have run")
        XCTAssertEqual(coordinator.stack.value.count, 2,
            "A screen opened from onDismiss must survive the pop that triggered it")
        XCTAssertEqual(coordinator.stack.value.last?.input as? String, "opened-from-onDismiss")
    }

    /// L8 — `popLast()` on an empty stack used to file its closure under the
    /// out-of-range key -2, where nothing would ever read or clear it. Whatever the
    /// closure captured was retained for the coordinator's lifetime.
    ///
    /// Fixed by deleting the dictionary: a completion is passed to the operation and
    /// released when it finishes, whether or not there was anything to remove.
    func testFixed_L8_popLastOnEmptyStack_retainsNothing() {
        XCTAssertEqual(coordinator.stack.value.count, 0)

        final class Captured {}
        weak var weakCaptured: Captured?
        autoreleasepool {
            let captured = Captured()
            weakCaptured = captured
            coordinator.popLast({ _ = captured })
        }

        XCTAssertNil(weakCaptured,
            "popLast() with nothing to pop must not strand its completion anywhere")
    }

    /// L4 — a stale dismissal used to close whatever the user had opened since.
    ///
    /// The route in is a double tap: dismissing a coordinator twice. The first call
    /// removes it; the second used to reach `dismissChild` with a coordinator no longer
    /// in the stack, where the "just close the top one" fallback took down whatever had
    /// been opened in between.
    ///
    /// Written as a double tap rather than by handing `dismissChild` a stranger, because
    /// that is how it actually happens. Passing a coordinator you are not showing is
    /// programmer error and asserts.
    func testFixed_L4_dismissingTwice_doesNotCloseWhatWasOpenedSince() {
        let child = coordinator.route(to: \.childCoordinator)
        let concrete = child.unwrap(TestChildCoordinator.self)
        XCTAssertNotNil(concrete)

        concrete?.dismissCoordinator()
        XCTAssertEqual(coordinator.stack.value.count, 0, "precondition: the child is gone")

        // The user opens something else.
        coordinator.route(to: \.detailView)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        // The stale second tap arrives.
        var actionRan = false
        concrete?.dismissCoordinator { actionRan = true }

        XCTAssertEqual(coordinator.stack.value.count, 1,
            "a stale dismissal must not close the screen opened since")
        XCTAssertEqual(coordinator.stack.value.last?.route,
                       .declared(\TestNavigationCoordinator.detailView))
        XCTAssertTrue(actionRan, "the completion still runs — what it wanted closed is closed")
    }
}
