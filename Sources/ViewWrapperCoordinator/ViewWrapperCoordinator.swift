import Foundation
import SwiftUI
import UIKit

/// The NavigationViewCoordinator is used to represent a coordinator with a NavigationView
@MainActor
open class ViewWrapperCoordinator<T: Coordinatable, V: View>: Coordinatable {
    public func dismissChild<U: Coordinatable>(coordinator: U, action: (() -> Void)?) {
        guard let parent = self.parent else {
            assertionFailure("Can not dismiss a coordinator since no coordinator is presented.")
            return
        }
        
        parent.dismissChild(coordinator: self, action: action)
    }

    public weak var parent: ChildDismissable?
    public let child: T
    private let viewFactory: (any Coordinatable) -> (AnyView) -> V

    public func view() -> AnyView {
        AnyView(
            ViewWrapperCoordinatorView(coordinator: self, viewFactory(self))
        )
    }

    /// Hosts the wrapped view, then lets the child configure the controller.
    ///
    /// A wrapper builds no view controller of its own: there is one controller for wrapper
    /// *and* child, because the child is rendered as SwiftUI inside the wrapper's view. So
    /// the child is who gets to configure it — the wrapper's own customization point is the
    /// view factory it was constructed with, not a UIKit hook.
    ///
    /// Without this forward, wrapping a coordinator in `NavigationViewCoordinator` and then
    /// using it as a tab or routing to it silently discarded whatever the child set on its
    /// own controller — the same shape of hole as a teardown cascade that stops at the
    /// wrapper, and fixed the same way.
    public func viewController() -> UIViewController {
        hostedViewController()
    }

    /// `open` rather than `public`: a protocol extension's default is statically dispatched,
    /// so a subclass could not participate at all unless the hook is a class member.
    open func configure(_ viewController: UIViewController) {
        child.configure(viewController)
    }
    
    public init(_ childCoordinator: T, _ view: @escaping (AnyView) -> V) {
        self.child = childCoordinator
        self.viewFactory = { _ in { view($0) } }
        self.child.parent = self
    }
    
    public init(_ childCoordinator: T, _ view: @escaping (any Coordinatable) -> (AnyView) -> V) {
        self.child = childCoordinator
        self.viewFactory = view
        self.child.parent = self
    }
}

/// A wrapper decorates a coordinator, it does not replace it — so a teardown cascade
/// that stopped here would leave the wrapped coordinator's screens believing they were
/// still open, and their `onDismiss` closures would never run.
extension ViewWrapperCoordinator: CoordinatorChildForwarding {
    var forwardedChild: any Coordinatable { child }
}
