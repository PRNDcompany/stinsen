import Foundation
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

public protocol NavigationCoordinatable: Coordinatable {
    typealias Route = NavigationRoute
    typealias Root = NavigationRoute
    typealias Router = NavigationRouter<Self>
    associatedtype CustomizeViewType: View
    associatedtype RouterStoreType

    var routerStorable: RouterStoreType { get }
    
    var stack: NavigationStack<Self> { get }

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
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output
    
    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Self
    
    @discardableResult func root<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output
    
    @discardableResult func root<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Self
    
    func isRoot<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Bool
    
    func isRoot<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Bool

    func isRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool

    func isRoot<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool

    func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool

    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool

    func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool

    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool
    
    @discardableResult func hasRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output?
    
    @discardableResult func hasRoot<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output?
    
    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output?
    
    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output?
}

public extension NavigationCoordinatable {
    var routerStorable: Self {
        get {
            self
        }
    }
    
    weak var parent: ChildDismissable? {
        get {
            return stack.parent
        } set {
            stack.parent = newValue
        }
    }
    
    // Track if dismiss is in progress to prevent duplicate calls
    // Using a global variable since we can't have static properties in protocol extensions
    private var isDismissing: Bool {
        get {
            return DismissingCoordinators.shared.contains(self.id)
        }
        set {
            if newValue {
                DismissingCoordinators.shared.insert(self.id)
            } else {
                DismissingCoordinators.shared.remove(self.id)
            }
        }
    }

    func customize(_ view: AnyView) -> some View {
        return view
    }
    
    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)? = nil) {
        
        // Check if already dismissing to prevent duplicate calls
        if coordinator is NavigationCoordinatable {
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
            // Check if the presentable is a Coordinatable (which always has an id)
            guard let presentable = item.presentable as? any Coordinatable else {
                return false
            }
            
            let matches = presentable.id == coordinator.id
            if matches {
            }
            return matches
        }) else {
            // Coordinator not found - check if it's the last item (common case)
            if stack.value.count > 0 {
                
                // If we have items in stack but can't find the coordinator,
                // it might be a re-entry scenario where IDs changed
                // In this case, just pop the last item
                if stack.value.count > 0 {
                    // Create wrapper action to clear flag after completion
                    let wrappedAction = {
                        action?()
                        (coordinator as? any NavigationCoordinatable)?.isDismissing = false
                    }
                    self.popTo(stack.value.count - 2, wrappedAction)
                    return
                }
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
        stack.parent!.dismissChild(coordinator: self, action: action)
    }
    
    internal func setupRoot() {
        let a = self[keyPath: self.stack.initial] as! NavigationOutputable
        let presentable = a.using(coordinator: self, input: self.stack.initialInput as Any)
        
        let item = NavigationRootItem(
            keyPath: self.stack.initial.hashValue,
            input: self.stack.initialInput,
            child: presentable
        )
        
        self.stack.root = NavigationRoot(item: item)
    }
    
    internal func appear(_ int: Int) {
        // NOTE: Original implementation called popTo(int, nil) which is incorrect.
        // "appear" should not trigger navigation changes, it should only track visibility.
        // Navigation changes should be explicit through push/pop/dismiss methods.
        
        // For now, we'll just track the appearance without causing navigation side effects.
        // If you need to sync navigation state, do it explicitly, not as a side effect of appearing.
        
        // Could potentially track visible view controllers here if needed:
        // self.visibleIndex = int
    }

    internal func disappear(_ id: Int) {
        
        // Execute dismissal action if exists
        if let action = stack.dismissalAction[id] {
            action()
        } else {
        }
        stack.dismissalAction[id] = nil
        
        // IMPORTANT: When a view disappears (is dismissed), we should also clean up the stack
        // Special handling for root coordinator (id = -1)
        if id == -1 && stack.value.count > 0 {
            // Remove the last item from the stack (the one that was just dismissed)
            stack.popToIndex(stack.value.count - 2)
        } else if id >= 0 && id < stack.value.count {
            // Pop to the previous item (id - 1)
            stack.popToIndex(id - 1)
        } else {
        }
    }

    func popLast(_ action: (() -> ())? = nil) {
        self.popTo(self.stack.value.count - 2, action)
    }
    
    internal func popTo(_ int: Int, _ action: (() -> ())? = nil) {
        if let action = action {
            self.stack.dismissalAction[int] = action
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
    
    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: @escaping () -> ()
    ) -> Output {
        stack.dismissalAction[stack.value.count - 1] = onDismiss
        return self.route(to: route, input)
    }
    
    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)
        let item = NavigationStackItem(
            presentationType: transition.type.type,
            presentable: output,
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
        stack.dismissalAction[stack.value.count - 1] = onDismiss
        return self.route(to: route)
    }
    
    @discardableResult func route<Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Output {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(())
        let item = NavigationStackItem(
            presentationType: transition.type.type,
            presentable: output,
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
        stack.dismissalAction[stack.value.count - 1] = onDismiss
        return self.route(to: route, input)
    }
    
    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)
        let item = NavigationStackItem(
            presentationType: transition.type.type,
            presentable: output,
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
        stack.dismissalAction[stack.value.count - 1] = onDismiss
        return self.route(to: route)
    }
    
    @discardableResult func route<Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(())
        let item = NavigationStackItem(
            presentationType: transition.type.type,
            presentable: output,
            keyPath: route.hashValue,
            input: nil
        )
        stack.push(item)
        return self
    }

    @discardableResult private func _focusFirst<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: ((Input, Input) -> Bool))?
    ) throws -> Output {
        guard let value = stack.value.enumerated().first(where: { item in
            guard item.element.keyPath == route.hashValue else {
                return false
            }
            
            guard let input = input else {
                return true
            }
            
            guard let compareTo = item.element.input else {
                assertionFailure()
            }
            
            return input.comparator(compareTo as! Input, input.value)
        }) else {
            throw FocusError.routeNotFound
        }
        
        self.popTo(value.offset, nil)
        
        return value.element.presentable as! Output
    }
    
    @discardableResult private func _focusFirst<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: ((Input, Input) -> Bool))?
    ) throws -> Self {
        guard let value = stack.value.enumerated().first(where: { item in
            guard item.element.keyPath == route.hashValue else {
                return false
            }
            
            guard let input = input else {
                return true
            }
            
            guard let compareTo = item.element.input else {
                assertionFailure()
            }
            
            return input.comparator(compareTo as! Input, input.value)
        }) else {
            throw FocusError.routeNotFound
        }
        
        self.popTo(value.offset, nil)
        
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
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Output {
        if stack.root.item.keyPath == route.hashValue {
            if let inputItem = inputItem {
                if inputItem.comparator(inputItem.input, stack.root.item.input! as! Input) == true {
                    return stack.root.item.child as! Output
                }
            } else {
                return stack.root.item.child as! Output
            }
        }
        
        let output: Output
        
        if let input = inputItem?.input {
            output = self[keyPath: route].closure(self)(input)
        } else {
            output = self[keyPath: route].closure(self)(() as! Input)
        }
        
        stack.root.item = NavigationRootItem(
            keyPath: route.hashValue,
            input: inputItem?.input,
            child: output
        )
        
        return output
    }
    
    @discardableResult private func _root<Output: View, Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Self {
        if stack.root.item.keyPath == route.hashValue {
            if let inputItem = inputItem {
                if inputItem.comparator(inputItem.input, stack.root.item.input! as! Input) == true {
                    return self
                }
            } else {
                return self
            }
        }
        
        let output: Output
        
        if let input = inputItem?.input {
            output = self[keyPath: route].closure(self)(input)
        } else {
            output = self[keyPath: route].closure(self)(() as! Input)
        }
        
        stack.root.item = NavigationRootItem(
            keyPath: route.hashValue,
            input: inputItem?.input,
            child: AnyView(output)
        )
        
        return self
    }
    
    @discardableResult func root<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output {
        self._root(route, inputItem: nil)
    }
    
    @discardableResult func root<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Self {
        self._root(route, inputItem: nil)
    }
    
    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output {
        self._root(route, inputItem: nil)
    }
    
    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Self {
        self._root(route, inputItem: nil)
    }
    
    @discardableResult func root<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output {
        self._root(route, inputItem: (input, comparator))
    }
    
    @discardableResult func root<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Self {
        self._root(route, inputItem: (input, comparator))
    }
    
    @discardableResult func root<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output {
        self._root(route, inputItem: (input, { $0 == $1 }))
    }
    
    @discardableResult func root<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Self {
        self._root(route, inputItem: (input, { $0 == $1 }))
    }
    
    private func _isRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Bool {
        guard stack.root.item.keyPath == route.hashValue else {
            return false
        }
        
        guard let inputItem = inputItem else {
            return true
        }

        guard let compareTo = stack.root.item.input else {
            assertionFailure()
        }

        return inputItem.comparator(compareTo as! Input, inputItem.input)
    }
    
    private func _isRoot<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Bool {
        guard stack.root.item.keyPath == route.hashValue else {
            return false
        }
        
        guard let inputItem = inputItem else {
            return true
        }

        guard let compareTo = stack.root.item.input else {
            assertionFailure()
        }

        return inputItem.comparator(compareTo as! Input, inputItem.input)
    }
    
    private func _hasRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        inputItem: (input: Input, comparator: (Input, Input) -> Bool)?
    ) -> Output? {
        return _isRoot(route, inputItem: inputItem) ? (stack.root.item.child as! Output) : nil
    }
    
    @discardableResult func isRoot<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Bool {
        return self._isRoot(route, inputItem: nil)
    }
    
    @discardableResult func isRoot<Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Bool {
        return self._isRoot(route, inputItem: nil)
    }

    @discardableResult func isRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool {
        return self._isRoot(route, inputItem: nil)
    }

    @discardableResult func isRoot<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool {
        return self._isRoot(route, inputItem: nil)
    }

    @discardableResult func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool {
        return self._isRoot(route, inputItem: (input: input, comparator: { $0 == $1 }))
    }

    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Bool {
        return self._isRoot(route, inputItem: (input: input, comparator: { $0 == $1 }))
    }

    func isRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool {
        return self._isRoot(route, inputItem: (input: input, comparator: comparator))
    }

    func isRoot<Input: Equatable, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Bool {
        return self._isRoot(route, inputItem: (input: input, comparator: comparator))
    }
    
    @discardableResult func hasRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output? {
        return self._hasRoot(route, inputItem: nil)
    }
    
    @discardableResult func hasRoot<Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Output>>
    ) -> Output? {
        return self._hasRoot(route, inputItem: nil)
    }
    
    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input
    ) -> Output? {
        return self._hasRoot(route, inputItem: (input: input, comparator: { $0 == $1 }))
    }
    
    @discardableResult func hasRoot<Input: Equatable, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        _ input: Input,
        comparator: @escaping (Input, Input) -> Bool
    ) -> Output? {
        return self._hasRoot(route, inputItem: (input: input, comparator: comparator))
    }
}

// Helper class to track dismissing coordinators
// We need this because we can't have static stored properties in protocol extensions
private class DismissingCoordinators {
    static let shared = DismissingCoordinators()
    private var coordinators = Set<String>()
    
    private init() {}
    
    func contains(_ id: String) -> Bool {
        return coordinators.contains(id)
    }
    
    func insert(_ id: String) {
        coordinators.insert(id)
    }
    
    func remove(_ id: String) {
        coordinators.remove(id)
    }
}
