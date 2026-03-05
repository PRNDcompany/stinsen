import Foundation
import SwiftUI
import UIKit

public final class NavigationRouter<T>: Routable {
    public let id: Int
    public var coordinator: T {
        guard let value = _coordinator.value as? T else {
            preconditionFailure("NavigationRouter: coordinator has been deallocated")
        }
        return value
    }
    
    private var _coordinator: WeakRef<AnyObject>
    
    // Weak reference to the view controller associated with this router
    weak var viewController: UIViewController?
    
    public init(id: Int, coordinator: T) {
        self.id = id
        self._coordinator = WeakRef(value: coordinator as AnyObject)
    }
}

@MainActor
public extension NavigationRouter where T: NavigationCoordinatable {
    /**
     Clears the stack.
     */
    @discardableResult func popToRoot(_ action: (() -> ())? = nil) -> T {
        coordinator.popToRoot(action)
    }
    
    func pop(_ action: (() -> ())? = nil) {
        // Try UIKit-based navigation first
        if let currentVC = viewController {
            let stack = coordinator.stack
            if let currentIndex = stack.indexOfViewController(currentVC),
               currentIndex > 0 {
                // Pop to the previous view controller
                coordinator.popTo(currentIndex - 1, action)
                return
            }
        }
        
        // Fallback to ID-based navigation
        coordinator.popTo(self.id - 1, action)
    }
    
    func popLast(_ action: (() -> ())? = nil) {
        coordinator.popLast(action)
    }
    
    func dismissCoordinator(_ action: (() -> ())? = nil) {
        coordinator.dismissCoordinator(action)
    }
    
    /**
     Appends a view to the navigation stack.

     - Parameter route: The route to append.
     - Parameter input: The parameters that are used to create the coordinator.
     */
    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<T, Transition<T, Presentation, Input, Output>>,
        _ input: Input
    ) -> T {
        coordinator.route(to: route, input)
    }
    
    /**
     Appends a coordinator to the navigation stack.

     - Parameter route: The route to append.
     - Parameter input: The parameters that are used to create the coordinator.
     */
    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<T, Transition<T, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output {
        coordinator.route(to: route, input)
    }
    
    /**
     Appends a coordinator to the navigation stack.

     - Parameter route: The route to append.
     */
    @discardableResult func route<Output: Coordinatable>(
        to route: KeyPath<T, Transition<T, Presentation, Void, Output>>
    ) -> Output {
        coordinator.route(to: route)
    }
    
    /**
     Appends a view to the navigation stack.

     - Parameter route: The route to append.
     */
    @discardableResult func route<Output: View>(
        to route: KeyPath<T, Transition<T, Presentation, Void, Output>>
    ) -> T {
        coordinator.route(to: route)
    }
    
    // MARK: - Imperative Route API

    /**
     Presents a view with the given presentation type without requiring a pre-declared @Route.

     - Parameter presentationType: The presentation type (e.g. .push(), .modal(), .popupModal()).
     - Parameter view: The view to present.
     - Parameter onDismiss: Optional closure called when the presented view is dismissed.
     */
    @discardableResult func route<Content: View>(
        _ presentationType: AnyPresentationType,
        to view: Content,
        onDismiss: (() -> Void)? = nil
    ) -> T {
        coordinator.route(presentationType, to: view, onDismiss: onDismiss)
    }

    /**
     Presents a coordinator with the given presentation type without requiring a pre-declared @Route.

     - Parameter presentationType: The presentation type (e.g. .push(), .modal(), .popupModal()).
     - Parameter coordinator: The coordinator to present.
     - Parameter onDismiss: Optional closure called when the presented coordinator is dismissed.
     */
    @discardableResult func route<Output: Coordinatable>(
        _ presentationType: AnyPresentationType,
        to coordinator: Output,
        onDismiss: (() -> Void)? = nil
    ) -> Output {
        self.coordinator.route(presentationType, to: coordinator, onDismiss: onDismiss)
    }

    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.

     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, Presentation, Void, Output>>
    ) throws -> Output {
        try coordinator.focusFirst(route)
    }
    
    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Output: View>(
        _ route: KeyPath<T, Transition<T, Presentation, Void, Output>>
    ) throws -> T {
        try coordinator.focusFirst(route)
    }
    
    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     - Parameter input: The input that will be considered.
     - Parameter comparator: The function to use to determine if the inputs are equal
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Output {
        try coordinator.focusFirst(route, input, comparator: comparator)
    }
    
    /**
     Searches the stack for the first route that matches the closure. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     - Parameter input: The input that will be considered.
     - Parameter comparator: The function to use to determine if the inputs are equal
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input, Output: View>(
        _ route: KeyPath<T, Transition<T, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> T {
        try coordinator.focusFirst(route, input, comparator: comparator)
    }
    
    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     - Parameter input: The input that will be considered. Since this function assumes input is Equatable, it will use the `==` function to determine equality.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Output {
        try coordinator.focusFirst(route, input)
    }
    
    /**
     Searches the stack for the first route that matches the closure. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     - Parameter input: The input that will be considered. Since this function assumes input is Equatable, it will use the `==` function to determine equality.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input: Equatable, Output: View>(
        _ route: KeyPath<T, Transition<T, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> T {
        try coordinator.focusFirst(route, input)
    }
    
    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, Presentation, Input, Output>>
    ) throws -> Output {
        try coordinator.focusFirst(route)
    }
    /**
     Searches the stack for the first route that matches the closure. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input, Output: View>(
        _ route: KeyPath<T, Transition<T, Presentation, Input, Output>>
    ) throws -> T {
        try coordinator.focusFirst(route)
    }
    
    @discardableResult func root<Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Void, Output>>
    ) -> Output {
        return coordinator.root(route)
    }
    
    @discardableResult func root<Output: View>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Void, Output>>
    ) -> T {
        return coordinator.root(route)
    }
    
    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>
    ) -> Output {
        return coordinator.root(route)
    }

    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>
    ) -> T {
        return coordinator.root(route)
    }

    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output {
        return coordinator.root(route, input)
    }

    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> T {
        return coordinator.root(route, input)
    }

    func isRoot<Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Void, Output>>
    ) -> Bool {
        return coordinator.isRoot(route)
    }
    
    func isRoot<Output: View>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Void, Output>>
    ) -> Bool {
        return coordinator.isRoot(route)
    }

    func isRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>
    ) -> Bool {
        return coordinator.isRoot(route)
    }

    func isRoot<Input, Output: View>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>
    ) -> Bool {
        return coordinator.isRoot(route)
    }

    func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool {
        return coordinator.isRoot(route, input)
    }

    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool {
        return coordinator.isRoot(route, input)
    }

    func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool {
        return coordinator.isRoot(route, input, comparator: comparator)
    }

    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool {
        return coordinator.isRoot(route, input, comparator: comparator)
    }
    
    @discardableResult func hasRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>
    ) -> Output? {
        return coordinator.hasRoot(route)
    }
    
    @discardableResult func hasRoot<Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Void, Output>>
    ) -> Output? {
        return coordinator.hasRoot(route)
    }
    
    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output? {
        return coordinator.hasRoot(route, input)
    }
    
    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<T, Transition<T, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output? {
        return coordinator.hasRoot(route, input, comparator: comparator)
    }
}
