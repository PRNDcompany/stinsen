import UIKit

/// Reads the screens currently stacked above a coordinator's base view controller,
/// in the order the user would go back through them.
///
/// The single place the hierarchy is walked, so that "what is on screen", "where do we
/// present from" and "what are we about to close" cannot disagree — if they could, the
/// coordinator would be back to holding a second opinion about a tree UIKit already owns.
///
/// One holdout remains: `CoordinatorMemoryLeakDetector` walks presentations of its own.
@MainActor
enum ScreenChain {

    /// Every screen above `base`, nearest first.
    ///
    /// Containers (`UINavigationController`, `UITabBarController`) are **not** included:
    /// they are not screens, they hold screens, and emitting them would make membership
    /// checks match things the coordinator never presented.
    static func walk(from base: UIViewController) -> [UIViewController] {
        var out: [UIViewController] = []
        var visited = Set<ObjectIdentifier>([ObjectIdentifier(base)])
        var cursor = base

        // Terminates because every iteration must emit at least one previously unseen
        // view controller, and `visited` only grows.
        while true {
            let countBefore = out.count

            // Screens pushed after the cursor inside the same navigation controller.
            if let nav = cursor.navigationController,
               let entry = cursor.navigationStackEntry,
               let index = nav.viewControllers.firstIndex(of: entry) {
                append(nav.viewControllers.dropFirst(index + 1), to: &out, visited: &visited)
                cursor = nav.viewControllers.last ?? cursor
            }

            // Checked after the branch above rather than instead of it: a screen can
            // both sit in a navigation controller and hold one, and after that branch
            // the cursor has moved to the topmost screen — which is the one that might
            // be holding it.
            if let nav = cursor.containedNavigationController {
                // A navigation controller the cursor *holds* rather than sits in.
                //
                // This is what a SwiftUI `NavigationView` looks like from UIKit: hosting
                // a `NavigationView` gives you a `UIHostingController` with the
                // `UINavigationController` as its child, so `cursor.navigationController`
                // is nil and the screens inside are invisible from above. Presenting a
                // coordinator wrapped in a `NavigationView` and then pushing is exactly
                // this shape, and without descending the push would target no navigation
                // controller at all and silently do nothing.
                append(nav.viewControllers, to: &out, visited: &visited)
                cursor = nav.viewControllers.last ?? cursor
            }

            // Then whatever is presented on top of it. `presentedViewController` reads
            // through ancestors, so asking the cursor is enough even when the
            // presentation was made by a container above it.
            if let presented = cursor.presentedViewController {
                if let nav = presented as? UINavigationController {
                    // Unwrap: the container is not a screen, its contents are.
                    append(nav.viewControllers, to: &out, visited: &visited)
                    cursor = nav.viewControllers.last ?? presented
                } else {
                    append([presented], to: &out, visited: &visited)
                    cursor = presented
                }
            }

            if out.count == countBefore { return out }
        }
    }

    private static func append<S: Sequence<UIViewController>>(
        _ screens: S,
        to out: inout [UIViewController],
        visited: inout Set<ObjectIdentifier>
    ) {
        for screen in screens where visited.insert(ObjectIdentifier(screen)).inserted {
            out.append(screen)
        }
    }
}

extension UIViewController {

    /// The ancestor (or self) that sits directly in `navigationController.viewControllers`.
    ///
    /// A pushed screen is often wrapped — a hosting controller inside another container —
    /// so the view controller you hold is rarely the one the navigation controller knows
    /// about. This finds the one it does.
    var navigationStackEntry: UIViewController? {
        guard let nav = navigationController else { return nil }
        var candidate: UIViewController? = self
        while let current = candidate, current.parent !== nav {
            candidate = current.parent
        }
        return candidate
    }

    /// The nearest navigation controller held *inside* this view controller.
    ///
    /// Breadth-first, so the outermost one wins when a screen contains several — but
    /// never into a container's inactive children. "First" is not "on screen" for a tab
    /// bar controller or a split view controller, and the answer decides where the next
    /// screen is pushed: descending into tab 0 while the user is looking at tab 2 pushes
    /// onto a stack nobody can see, and the push is neither visible nor recoverable.
    var containedNavigationController: UINavigationController? {
        var queue = visibleChildren
        var index = 0
        while index < queue.count {
            let candidate = queue[index]
            index += 1
            if let nav = candidate as? UINavigationController { return nav }
            queue.append(contentsOf: candidate.visibleChildren)
        }
        return nil
    }

    /// The children worth descending into: a container's active child, or all of them.
    ///
    /// Asking the container rather than reading `children` in order, because only the
    /// container knows which of its children it is showing — and for everything else
    /// "all of them" is right, since a plain view controller's children are all on screen
    /// together.
    private var visibleChildren: [UIViewController] {
        if let tabs = self as? UITabBarController {
            return [tabs.selectedViewController].compactMap { $0 }
        }
        if let split = self as? UISplitViewController {
            // The trailing column is the one a push belongs in — the same one UIKit
            // shows on its own when the display mode collapses to a single column.
            return [split.viewControllers.last].compactMap { $0 }
        }
        return children
    }

    /// Whether this view controller is still attached to anything at all.
    ///
    /// Cause-agnostic and container-agnostic on purpose: it answers "is this screen
    /// still alive" for a push, a presentation, a child-containment overlay, or a
    /// separate window, without needing to know which it was.
    ///
    /// Uses `viewIfLoaded` rather than `view`: `view` is lazy, so touching it would
    /// load the view and run `viewDidLoad` — a liveness *check* that creates the thing
    /// it is checking.
    var isAttachedToHierarchy: Bool {
        isBeingPresented
            || presentingViewController != nil
            || presentedViewController != nil
            || parent != nil
            || navigationController != nil
            || tabBarController != nil
            || splitViewController != nil
            || viewIfLoaded?.window != nil
    }
}
