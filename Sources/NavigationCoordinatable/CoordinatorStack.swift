import Foundation
import SwiftUI
import UIKit

/// A coordinator's navigation state: which route it started from, and the screens it has
/// opened since.
///
/// It no longer *is* the stack. The screens are owned by `NavigationHost`, which reads
/// their order and their liveness back from UIKit; this type holds the two things UIKit
/// cannot know — where the flow started, and who to hand a dismissal up to.
@MainActor
public class CoordinatorStack<T: NavigationCoordinatable> {

    weak var parent: ChildDismissable?

    /// Owned here rather than by a view controller: the coordinator outlives any
    /// particular rendering of itself, and screens routed to before the first render
    /// have to survive until there is somewhere to put them.
    let host = NavigationHost()

    let initial: PartialKeyPath<T>
    let initialInput: Any?
    var root: NavigationRoot!

    /// Every screen this coordinator has opened, in the order UIKit holds them.
    ///
    /// Includes screens that have been recorded but not yet presented — routing before
    /// the first render is legitimate, and pretending those do not exist would make
    /// `route(...)` followed by `popLast()` behave differently depending on render
    /// timing.
    var value: [RouteRecord] { host.records }

    public init(initial: PartialKeyPath<T>, _ initialInput: Any? = nil) {
        self.initial = initial
        self.initialInput = initialInput
        self.root = nil
    }
}

/// Convenience checks against what is currently on screen.
public extension CoordinatorStack {

    /// The route at the top of the stack, or `nil` when the coordinator is showing only
    /// its root.
    ///
    /// Derived from UIKit on every read, so it cannot report a screen the user has
    /// already closed — including one closed by something other than this coordinator.
    var currentRouteKey: RouteKey? {
        host.liveRecords().last?.route
    }

    /// Whether a declared route is currently on screen.
    func isInStack(_ keyPath: AnyKeyPath) -> Bool {
        let key = RouteKey.declared(keyPath)
        return host.liveRecords().contains { $0.route == key }
    }

    /**
        The Hash of the route at the top of the stack
        - Returns: the hash of the route at the top of the stack or -1
     */
    @available(*, deprecated, renamed: "currentRouteKey")
    var currentRoute: Int {
        host.liveRecords().last?.keyPath ?? -1
    }

    /**
    Checks if a particular KeyPath is in a stack
     - Parameter keyPathHash:The hash of the keyPath
     - Returns: Boolean indiacting whether the route is in the stack
     */
    @available(*, deprecated, message: "Use isInStack(_ keyPath: AnyKeyPath) — hashes can collide")
    func isInStack(_ keyPathHash: Int) -> Bool {
        host.liveRecords().contains { $0.keyPath == keyPathHash }
    }
}

/// Preserves compile-time type information from route methods.
/// Route methods know whether Output is View or Coordinatable via generics —
/// this enum carries that distinction through the stack instead of erasing it to ViewPresentable.
@MainActor
public enum StackItemContent {
    case view(AnyView)
    case coordinator(any Coordinatable)
}

// MARK: - Deprecated

@available(*, deprecated, renamed: "CoordinatorStack")
public typealias NavigationStack = CoordinatorStack
