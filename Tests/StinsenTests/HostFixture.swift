//
//  HostFixture.swift
//  StinsenTests
//
//  A real window, a real navigation controller, and a coordinator bound to it.
//
//  Most tests need no hierarchy at all: a coordinator with nothing bound records its
//  screens and answers every query, which is the deep-link case and worth keeping
//  cheap. But the questions this refactor turns on — "did UIKit still have it?", "what
//  happens when something else closes a screen?" — cannot be asked of a coordinator
//  that has never met UIKit. Those need this.
//

import UIKit
@testable import Stinsen

@MainActor
final class HostFixture {

    let window: UIWindow
    let navigation: UINavigationController

    /// The screen the coordinator hangs its own off — the same role the SwiftUI anchor
    /// plays in a real app.
    let base = UIViewController()

    init<T: NavigationCoordinatable>(coordinator: T) {
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        navigation = UINavigationController(rootViewController: base)
        window.rootViewController = navigation
        // Visible, not merely allocated: `presentationContext()` refuses to present from
        // a view controller that is not in a window, which is exactly the guard that
        // stops a coordinator putting a screen onto something already gone.
        window.makeKeyAndVisible()
        navigation.loadViewIfNeeded()
        base.loadViewIfNeeded()
        // Without a layout pass `base.view` has not been added to the window yet, and a
        // host with no presentation context records screens instead of presenting them —
        // which would make every test here quietly measure the deep-link path instead.
        window.layoutIfNeeded()

        coordinator.host.bind(base: base)
        // Asks about the fixture, not about the queue. `presentationContext()` used to
        // stand in for this and conflated two things: a coordinator that already had a
        // screen recorded puts it up during `bind`, and from inside that transition the
        // context is legitimately nil — so a fixture built for a deep-link test tripped a
        // precondition about being off screen while being perfectly on screen.
        precondition(base.viewIfLoaded?.window != nil,
                     "fixture is not on screen; the coordinator would have nowhere to present")
    }

    /// Lets UIKit finish whatever transition is in flight.
    ///
    /// Not optional politeness. Navigation animates, and the host waits for each
    /// transition before starting the next — so with no run loop being pumped, a
    /// deferred screen never gets its turn and the test measures a stalled queue rather
    /// than the behaviour it is asking about. Tests wait the same way a user does.
    func settle(_ duration: TimeInterval = 0.8) {
        RunLoop.current.run(until: Date().addingTimeInterval(duration))
    }

    /// Pumps the run loop until `condition` holds, then stops.
    ///
    /// Preferred over `settle(_:)` wherever a test is waiting for one specific outcome. A
    /// fixed duration is a bet that the machine is as idle as it was when the number was
    /// chosen: a push takes about a third of a second on its own, plus whatever the queue
    /// waits before retrying, and running the suite makes both longer. When that bet loses
    /// the failure reads as the behaviour being wrong rather than the wait being short,
    /// which is the most expensive kind of test to own.
    ///
    /// Returns as soon as the condition holds, so a passing test also stops paying for the
    /// wait it did not need.
    func settle(until condition: () -> Bool, timeout: TimeInterval = 3) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }

    deinit {
        window.isHidden = true
    }
}
