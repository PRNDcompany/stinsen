import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
public protocol NavigationCoordinatable: Coordinatable {
    typealias Route = NavigationRoute
    typealias Root = NavigationRoute
    associatedtype CustomizeViewType: View

    var stack: CoordinatorStack<Self> { get }

    /**
     Implement this function if you wish to customize the view on all views and child coordinators, for instance, if you wish to change the `tintColor` or inject an `EnvironmentObject`.
     - Parameter view: The input view.
     - Returns: The modified view.
     */
    func customize(_ view: AnyView) -> CustomizeViewType
    
    func dismissCoordinator(_ action: (() -> ())?)
    
    /**
     Clears the stack.
     */
    @discardableResult func popToRoot(_ action: (() -> ())?) -> Self

    /**
     Appends a view to the navigation stack.

     - Parameter route: The route to append.
     - Parameter input: The parameters that are used to create the coordinator.
     */
    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Self
    
    /**
     Appends a coordinator to the navigation stack.

     - Parameter route: The route to append.
     - Parameter input: The parameters that are used to create the coordinator.
     */
    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output
    
    /**
     Appends a coordinator to the navigation stack.

     - Parameter route: The route to append.
     */
    @discardableResult func route<Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Output
    
    /**
     Appends a view to the navigation stack.

     - Parameter route: The route to append.
     */
    @discardableResult func route<Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Self
    
    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) throws -> Output
    
    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) throws -> Self
    
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
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Output
    
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
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Self
    
    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     - Parameter input: The input that will be considered. Since this function assumes input is Equatable, it will use the `==` function to determine equality.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Output
    
    /**
     Searches the stack for the first route that matches the closure. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     - Parameter input: The input that will be considered. Since this function assumes input is Equatable, it will use the `==` function to determine equality.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Self
    
    /**
     Searches the stack for the first route that matches the route. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Output
    
    /**
     Searches the stack for the first route that matches the closure. If found, will remove
     everything after that route.

     - Parameter route: The route that will be focused.
     
     - Throws: `FocusError.routeNotFound`
               if the route was not found in the stack.
     */
    @discardableResult func focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Self
    
    @discardableResult func root<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output
    
    @discardableResult func root<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Self
    
    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output
    
    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Self
    
    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output

    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Self
}

@MainActor
public extension NavigationCoordinatable {
    weak var parent: ChildDismissable? {
        get {
            return stack.parent
        } set {
            stack.parent = newValue
        }
    }
    
    // Track if dismiss is in progress to prevent duplicate calls
    // Uses NSHashTable with weak references for automatic cleanup on deallocation
    private var isDismissing: Bool {
        get {
            return DismissingCoordinators.shared.contains(self)
        }
        set {
            if newValue {
                DismissingCoordinators.shared.insert(self)
            } else {
                DismissingCoordinators.shared.remove(self)
            }
        }
    }

    func customize(_ view: AnyView) -> some View {
        return view
    }
    
    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)? = nil) {
        
        // Track for memory leak in debug mode
        #if DEBUG
        coordinator.trackForMemoryLeak()
        #endif
        
        // Check if already dismissing to prevent duplicate calls
        if coordinator is (any NavigationCoordinatable) {
            if let navCoordinator = coordinator as? any NavigationCoordinatable,
               navCoordinator.isDismissing {
                return
            }
            (coordinator as? any NavigationCoordinatable)?.isDismissing = true
        }
        
        // First check if the stack is empty - nothing to dismiss
        guard !stack.value.isEmpty else {
            action?() // Still call the action if provided
            (coordinator as? any NavigationCoordinatable)?.isDismissing = false
            return
        }
        
        // Try to find the coordinator in the stack
        guard let value = stack.value.firstIndex(where: { item in
            guard case .coordinator(let presentable) = item.content else {
                return false
            }
            
            let matches = presentable.id == coordinator.id
            if matches {
            }
            return matches
        }) else {
            // Coordinator not found in stack - pop the last item as fallback
            if !stack.value.isEmpty {
                let wrappedAction = {
                    action?()
                    (coordinator as? any NavigationCoordinatable)?.isDismissing = false
                }
                self.popTo(stack.value.count - 2, wrappedAction)
                return
            }
            action?() // Still call the action if provided
            (coordinator as? any NavigationCoordinatable)?.isDismissing = false
            return
        }
        // Create wrapper action to clear flag after completion
        let wrappedAction = {
            action?()
            (coordinator as? any NavigationCoordinatable)?.isDismissing = false
        }
        self.popTo(value - 1, wrappedAction)
    }
    
    func dismissCoordinator(_ action: (() -> ())? = nil) {
        guard let parent = stack.parent else {
            assertionFailure("dismissCoordinator: no parent and no SwiftUI dismiss available")
            return
        }
        parent.dismissChild(coordinator: self, action: action)
    }
    
    internal func setupRoot() {
        let initial = self[keyPath: self.stack.initial] as! NavigationOutputable
        let presentable = initial.using(coordinator: self, input: self.stack.initialInput as Any)

        let item = NavigationRootItem(
            keyPath: self.stack.initial.hashValue,
            input: self.stack.initialInput,
            child: presentable
        )
        
        let transition = (initial as? NavigationRootOutputable)?.routeTransition
        self.stack.root = NavigationRoot(item: item, transition: transition ?? .identity)
    }
    
    /// Called when a view controller appears. Intentionally a no-op;
    /// navigation state changes should be explicit through push/pop/dismiss.
    internal func appear(_ int: Int) { }

    internal func disappear(deadUid: UUID) {
        // Clean the stack only if the dead item is still in it (e.g. gesture pop).
        // Judged before running callbacks so a late report never evicts a slot's new tenant.
        if let deadIndex = stack.value.firstIndex(where: { $0.uid == deadUid }) {
            stack.popToIndex(deadIndex - 1)
        }

        let actions = stack.dismissalAction.removeValue(forKey: deadUid) ?? []
        actions.forEach { $0() }
    }

    func popLast(_ action: (() -> ())? = nil) {
        self.popTo(self.stack.value.count - 2, action)
    }
    
    internal func popTo(_ int: Int, _ action: (() -> ())? = nil) {
        if let action = action {
            if let bottomRemoved = stack.value[safe: int + 1] {
                // Completion fires when the bottom-most removed item reports its death.
                stack.dismissalAction[bottomRemoved.uid, default: []].append(action)
            } else {
                // Nothing to remove — the pop completes trivially.
                action()
            }
        }

        stack.popToIndex(int)
    }
    
    func view() -> AnyView {
        return AnyView(NavigationCoordinatableView(id: -1, coordinator: self))
    }

    @discardableResult func popToRoot(_ action: (() -> ())? = nil) -> Self {
        self.popTo(-1, action)
        return self
    }
    
    private func registerDismissalAction(_ onDismiss: (() -> Void)?, forItemUid uid: UUID) {
        guard let onDismiss = onDismiss else { return }
        stack.dismissalAction[uid, default: []].append(onDismiss)
    }

    /// Runs a route call and registers onDismiss on the item it pushed.
    /// Skipped when the duplicate-push guard dropped the push.
    private func routeRegisteringDismissal<Output>(
        _ onDismiss: @escaping () -> Void,
        perform route: () -> Output
    ) -> Output {
        let countBefore = stack.value.count
        let output = route()
        if stack.value.count > countBefore, let uid = stack.value.last?.uid {
            registerDismissalAction(onDismiss, forItemUid: uid)
        }
        return output
    }

    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: @escaping () -> ()
    ) -> Output {
        routeRegisteringDismissal(onDismiss) { self.route(to: route, input) }
    }
    
    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)
        let item = NavigationStackItem(
            presentationType: transition.type.type,
            content: .coordinator(output),
            keyPath: route.hashValue,
            input: input
        )
        stack.push(item)
        output.parent = self
        return output
    }

    @discardableResult func route<Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>,
        onDismiss: @escaping () -> ()
    ) -> Output {
        routeRegisteringDismissal(onDismiss) { self.route(to: route) }
    }

    @discardableResult func route<Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Output {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(())
        let item = NavigationStackItem(
            presentationType: transition.type.type,
            content: .coordinator(output),
            keyPath: route.hashValue,
            input: nil
        )
        stack.push(item)
        output.parent = self
        return output
    }

    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: @escaping () -> ()
    ) -> Self {
        routeRegisteringDismissal(onDismiss) { self.route(to: route, input) }
    }

    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)
        let item = NavigationStackItem(
            presentationType: transition.type.type,
            content: .view(AnyView(output)),
            keyPath: route.hashValue,
            input: input
        )
        stack.push(item)
        return self
    }

    @discardableResult func route<Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>,
        onDismiss: @escaping () -> ()
    ) -> Self {
        routeRegisteringDismissal(onDismiss) { self.route(to: route) }
    }

    @discardableResult func route<Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(())
        let item = NavigationStackItem(
            presentationType: transition.type.type,
            content: .view(AnyView(output)),
            keyPath: route.hashValue,
            input: nil
        )
        stack.push(item)
        return self
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
    ) -> Self {
        let item = NavigationStackItem(
            presentationType: presentationType,
            content: .view(AnyView(view)),
            keyPath: ImperativeRouteId.next(),
            input: nil
        )
        registerDismissalAction(onDismiss, forItemUid: item.uid)
        stack.push(item)
        return self
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
        let item = NavigationStackItem(
            presentationType: presentationType,
            content: .coordinator(coordinator),
            keyPath: ImperativeRouteId.next(),
            input: nil
        )
        registerDismissalAction(onDismiss, forItemUid: item.uid)
        stack.push(item)
        coordinator.parent = self
        return coordinator
    }

    /// Finds the first stack item matching the given route and input, then pops to it.
    /// Returns the matched item for further processing.
    @discardableResult
    private func _popToFirstMatch<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: ((Input, Input) -> Bool))?
    ) throws -> NavigationStackItem {
        guard let value = stack.value.enumerated().first(where: { item in
            guard item.element.keyPath == route.hashValue else {
                return false
            }

            guard let input = input else {
                return true
            }

            guard let compareTo = item.element.input else {
                assertionFailure("_focusFirst: expected input but got nil")
                return false
            }

            return input.comparator(compareTo as! Input, input.value)
        }) else {
            throw FocusError.routeNotFound
        }

        self.popTo(value.offset, nil)
        return value.element
    }

    @discardableResult private func _focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: ((Input, Input) -> Bool))?
    ) throws -> Output {
        let matched = try _popToFirstMatch(route, input)
        guard case .coordinator(let c) = matched.content else {
            assertionFailure("focusFirst: expected coordinator in stack")
            fatalError()
        }
        return c as! Output
    }

    @discardableResult private func _focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: ((Input, Input) -> Bool))?
    ) throws -> Self {
        try _popToFirstMatch(route, input)
        return self
    }
    
    @discardableResult func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) throws -> Output {
        try self._focusFirst(route, nil)
    }
    
    @discardableResult func focusFirst<Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) throws -> Self {
        try self._focusFirst(route, nil)
    }
    
    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Output {
        try self._focusFirst(route, (value: input, comparator: comparator))
    }
    
    @discardableResult func focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) throws -> Self {
        try self._focusFirst(route, (value: input, comparator: comparator))
    }
    
    @discardableResult func focusFirst<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Output {
        try self._focusFirst(route, (value: input, comparator: { $0 == $1 }))
    }
    
    @discardableResult func focusFirst<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) throws -> Self {
        try self._focusFirst(route, (value: input, comparator: { $0 == $1 }))
    }
    
    @discardableResult func focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Output {
        try self._focusFirst(route, nil)
    }
    
    @discardableResult func focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>
    ) throws -> Self {
        try self._focusFirst(route, nil)
    }
    
    @discardableResult private func _root<Output: Coordinatable, Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        input: Input? = nil,
        animation: Animation? = nil
    ) -> Output {
        let output: Output = _createRouteOutput(route, input: input)
        let newItem = NavigationRootItem(keyPath: route.hashValue, input: input, child: output)
        let rootSwitch = self[keyPath: route].type
        stack.root.updateItem(newItem, animation: animation, transition: rootSwitch.transition, zOrder: rootSwitch.zOrder)
        return output
    }

    @discardableResult private func _root<Output: View, Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        input: Input? = nil,
        animation: Animation? = nil
    ) -> Self {
        let output: Output = _createRouteOutput(route, input: input)
        let newItem = NavigationRootItem(keyPath: route.hashValue, input: input, child: AnyView(output))
        let rootSwitch = self[keyPath: route].type
        stack.root.updateItem(newItem, animation: animation, transition: rootSwitch.transition, zOrder: rootSwitch.zOrder)
        return self
    }

    /// Creates a route output by invoking the transition's closure with the given input.
    private func _createRouteOutput<U: RouteType, Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, U, Input, Output>>,
        input: Input?
    ) -> Output {
        if let input = input {
            return self[keyPath: route].closure(self)(input)
        } else {
            return self[keyPath: route].closure(self)(() as! Input)
        }
    }
    
    @discardableResult func root<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output {
        self._root(route)
    }

    @discardableResult func root<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Self {
        self._root(route)
    }

    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output {
        self._root(route)
    }

    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Self {
        self._root(route)
    }

    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output {
        self._root(route, input: input)
    }

    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Self {
        self._root(route, input: input)
    }

    // MARK: - Animation overloads (call-site animation, default params not allowed in protocol)

    @discardableResult func root<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>,
        animation: Animation?
    ) -> Output {
        self._root(route, animation: animation)
    }

    @discardableResult func root<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>,
        animation: Animation?
    ) -> Self {
        self._root(route, animation: animation)
    }

    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        animation: Animation?
    ) -> Output {
        self._root(route, input: input, animation: animation)
    }

    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        animation: Animation?
    ) -> Self {
        self._root(route, input: input, animation: animation)
    }
}

// Helper class to track dismissing coordinators
// Uses NSHashTable with weak references so entries auto-clean on deallocation
@MainActor
private class DismissingCoordinators {
    static let shared = DismissingCoordinators()
    private let coordinators = NSHashTable<AnyObject>.weakObjects()

    private init() {}

    func contains(_ coordinator: AnyObject) -> Bool {
        return coordinators.contains(coordinator)
    }

    func insert(_ coordinator: AnyObject) {
        coordinators.add(coordinator)
    }

    func remove(_ coordinator: AnyObject) {
        coordinators.remove(coordinator)
    }
}

// MARK: - Imperative Route ID Generator

/// Generates unique IDs for imperative route calls to avoid keyPath collisions.
/// Uses negative values to avoid collision with KeyPath.hashValue (typically positive).
private enum ImperativeRouteId {
    nonisolated(unsafe) private static var _counter = Int.min
    static func next() -> Int {
        defer { _counter += 1 }
        return _counter
    }
}
