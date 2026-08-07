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
        precondition(coordinator.host.presentationContext() != nil,
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

    deinit {
        window.isHidden = true
    }
}
