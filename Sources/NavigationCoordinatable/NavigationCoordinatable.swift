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
    
    /// This coordinator's screens, and the view controller they hang off.
    ///
    /// Bound to `self` on first use rather than at construction: `stack` is initialised
    /// in a property declaration, before there is a `self` to hand it.
    internal var host: NavigationHost {
        let host = stack.host
        if host.owner == nil {
            host.owner = self
            host.rootRoute = .declared(stack.initial)
        }
        return host
    }

    /// Drops this coordinator's screens without touching UIKit — the parent already did.
    internal func teardownHost() {
        stack.host.teardown()
    }

    func customize(_ view: AnyView) -> some View {
        return view
    }

    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)? = nil) {

        // Track for memory leak in debug mode
        #if DEBUG
        coordinator.trackForMemoryLeak()
        #endif

        host.reconcile()

        guard !stack.value.isEmpty else {
            action?() // Still call the action if provided
            return
        }

        // Identity, not `id` strings. Declared coordinator routes are stored wrapped in
        // `AnyCoordinator`, and the object calling `dismissCoordinator()` is the
        // coordinator inside the box — so both sides are unwrapped before comparing.
        let target = coordinatorInstance(coordinator)
        guard let index = stack.value.firstIndex(where: { $0.childObject === target }) else {
            // Coordinator not found in stack - pop the last item as fallback.
            // Guesswork, and it closes whatever happens to be on top: removing it is a
            // behaviour change and lands as its own commit.
            host.unwind(keepingFirst: stack.value.count - 1, animated: true, completion: action)
            return
        }
        host.unwind(keepingFirst: index, animated: true, completion: action)
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
    
    /// Closes the topmost screen.
    func popLast(_ action: (() -> ())? = nil) {
        host.reconcile()
        host.unwind(keepingFirst: stack.value.count - 1, animated: true, completion: action)
    }

    /// Rewinds to a screen opened with `route(_:to:id:)`.
    ///
    /// UIKit's unwind segue, without the storyboard: `popLast()` goes back one and
    /// `popToRoot()` goes back all the way, and until now there was nothing in between.
    ///
    /// When a name appears more than once this rewinds to the **nearest** one, which is
    /// what "go back to the list" means when you have been through two of them. Note
    /// that `focusFirst` does the opposite by design — hence the different verb.
    ///
    /// - Returns: whether a screen with that name was found.
    @discardableResult func popTo(id: String, _ action: (() -> ())? = nil) -> Bool {
        host.reconcile()
        guard let index = stack.value.lastIndex(where: { $0.route.name == id }) else {
            return false
        }
        host.unwind(keepingFirst: index + 1, animated: true, completion: action)
        return true
    }

    func view() -> AnyView {
        return AnyView(NavigationCoordinatableView(coordinator: self))
    }

    // `viewController()` is inherited: it hosts `view()`, so the root is rendered by
    // SwiftUI either way and `customize(_:)` — which is a SwiftUI modifier — keeps
    // applying. The cost is a root that is *itself* a `UIViewController` going through a
    // representable and a hosting controller to get there.
    //
    // Removing those two layers means a container that adds the root as a direct child
    // view controller, and then `customize(_:)` has nothing to wrap. That is a real
    // decision about what `customize` means for a UIKit root, not a detail to slip in
    // alongside something else.

    /// The coordinator wrapped in a navigation controller, ready to be a window's root.
    ///
    /// ```swift
    /// // SceneDelegate
    /// window.rootViewController = MainCoordinator().navigationController()
    /// ```
    ///
    /// Use this when the coordinator's routes include `.push` — a push needs a
    /// navigation controller in scope, and nothing else in a plain UIKit app is going to
    /// provide one. `viewController()` is the right entry point for a coordinator that
    /// only presents modally, or one that is being placed inside navigation the app
    /// already owns.
    func navigationController() -> UINavigationController {
        UINavigationController(rootViewController: viewController())
    }

    @discardableResult func popToRoot(_ action: (() -> ())? = nil) -> Self {
        host.reconcile()
        host.unwind(keepingFirst: 0, animated: true, completion: action)
        return self
    }

    /// Records a screen and asks the host to put it up.
    ///
    /// `onDismiss` is attached to the screen being opened, not to the one below it. The
    /// old keying — "store the action at the current top index" — is why routing from
    /// inside a dismissal handler used to be truncated by the very pop that triggered it.
    private func appendRecord(
        presentation: PresentationType,
        content: StackItemContent,
        route: RouteKey,
        keyPath: Int,
        input: Any?,
        onDismiss: (() -> Void)? = nil
    ) {
        host.reconcile()
        host.append(
            RouteRecord(
                route: route,
                keyPath: keyPath,
                input: input,
                content: content,
                presentation: AnyPresentationType(presentation),
                onDismiss: onDismiss
            )
        )
    }

    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: @escaping () -> ()
    ) -> Output {
        _route(to: route, input, onDismiss: onDismiss)
    }

    @discardableResult func route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Output {
        _route(to: route, input, onDismiss: nil)
    }

    @discardableResult func route<Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>,
        onDismiss: @escaping () -> ()
    ) -> Output {
        _route(to: route, (), onDismiss: onDismiss)
    }

    @discardableResult func route<Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Output {
        _route(to: route, (), onDismiss: nil)
    }

    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: @escaping () -> ()
    ) -> Self {
        _route(to: route, input, onDismiss: onDismiss)
    }

    @discardableResult func route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input
    ) -> Self {
        _route(to: route, input, onDismiss: nil)
    }

    @discardableResult func route<Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>,
        onDismiss: @escaping () -> ()
    ) -> Self {
        _route(to: route, (), onDismiss: onDismiss)
    }

    @discardableResult func route<Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Void, Output>>
    ) -> Self {
        _route(to: route, (), onDismiss: nil)
    }

    @discardableResult private func _route<Input, Output: Coordinatable>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: (() -> Void)?
    ) -> Output {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)
        appendRecord(
            presentation: transition.type.type,
            content: .coordinator(output),
            route: .declared(route),
            keyPath: route.hashValue,
            input: Input.self == Void.self ? nil : input,
            onDismiss: onDismiss
        )
        output.parent = self
        return output
    }

    @discardableResult private func _route<Input, Output: View>(
        to route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: Input,
        onDismiss: (() -> Void)?
    ) -> Self {
        let transition = self[keyPath: route]
        let output = transition.closure(self)(input)
        appendRecord(
            presentation: transition.type.type,
            content: .view(AnyView(output)),
            route: .declared(route),
            keyPath: route.hashValue,
            input: Input.self == Void.self ? nil : input,
            onDismiss: onDismiss
        )
        return self
    }

    // MARK: - Imperative Route API

    /**
     Presents a view with the given presentation type without requiring a pre-declared @Route.

     - Parameter presentationType: The presentation type (e.g. .push(), .modal(), .popupModal()).
     - Parameter view: The view to present.
     - Parameter id: Optional name for this screen, so it can be navigated back to later.
       Without one the screen is anonymous, which is the previous behaviour: reachable
       only by `popLast()` / `popToRoot()`, never by name.
     - Parameter onDismiss: Optional closure called when the presented view is dismissed.
     */
    @discardableResult func route<Content: View>(
        _ presentationType: AnyPresentationType,
        to view: Content,
        id: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> Self {
        appendRecord(
            presentation: presentationType,
            content: .view(AnyView(view)),
            route: id.map(RouteKey.named) ?? .anonymous(),
            keyPath: ImperativeRouteId.next(),
            input: nil,
            onDismiss: onDismiss
        )
        return self
    }

    /**
     Presents a view controller with the given presentation type.

     The view controller is presented as it is — it is not wrapped, subclassed or
     otherwise adapted, and nothing is attached to it. It gets exactly the same
     treatment as a SwiftUI screen from there on: the same lifecycle callbacks, the same
     place in `popLast()` / `popToRoot()` / `popTo(id:)`, and the same behaviour when
     something outside the coordinator closes it.

     ```swift
     coordinator.route(.push, to: ProductViewController(id: 42))
     coordinator.route(.modal, to: FilterViewController(), id: "filter")
     ```

     - Parameter presentationType: How to put it on screen. The built-in `.push`,
       `.modal` and `.fullScreen` accept any view controller; a presentation built with
       `AnyPresentationType(make:present:)` is typed to whatever its `make` closure
       returns and can only present that type.
     - Parameter viewController: The view controller to present.
     - Parameter id: Optional name for this screen, so it can be navigated back to later
       with `popTo(id:)`. Without one the screen is anonymous — reachable only by
       `popLast()` / `popToRoot()`, never by name.
     - Parameter onDismiss: Optional closure called when this screen goes away, whichever
       path removed it.
     */
    @discardableResult func route(
        _ presentationType: AnyPresentationType,
        to viewController: UIViewController,
        id: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> Self {
        appendRecord(
            presentation: presentationType,
            content: .viewController(viewController),
            route: id.map(RouteKey.named) ?? .anonymous(),
            keyPath: ImperativeRouteId.next(),
            input: nil,
            onDismiss: onDismiss
        )
        return self
    }

    /**
     Presents a coordinator with the given presentation type without requiring a pre-declared @Route.

     - Parameter presentationType: The presentation type (e.g. .push(), .modal(), .popupModal()).
     - Parameter coordinator: The coordinator to present.
     - Parameter id: Optional name for this screen, so it can be navigated back to later.
     - Parameter onDismiss: Optional closure called when the presented coordinator is dismissed.
     */
    @discardableResult func route<Output: Coordinatable>(
        _ presentationType: AnyPresentationType,
        to coordinator: Output,
        id: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> Output {
        appendRecord(
            presentation: presentationType,
            content: .coordinator(coordinator),
            route: id.map(RouteKey.named) ?? .anonymous(),
            keyPath: ImperativeRouteId.next(),
            input: nil,
            onDismiss: onDismiss
        )
        coordinator.parent = self
        return coordinator
    }

    /// Finds the first screen matching the given route and input, then rewinds to it.
    ///
    /// **First** match, not the nearest one — the opposite of `popTo(id:)`. Both are
    /// defensible ("go to where this flow started" vs. "go back one level") and only the
    /// names distinguish them, which is why the other one says `popTo` rather than
    /// `focusLast`.
    @discardableResult
    private func _popToFirstMatch<Input, Output: ViewPresentable>(
        _ route: KeyPath<Self, Transition<Self, Presentation, Input, Output>>,
        _ input: (value: Input, comparator: ((Input, Input) -> Bool))?
    ) throws -> RouteRecord {
        host.reconcile()
        let key = RouteKey.declared(route)
        guard let value = stack.value.enumerated().first(where: { item in
            guard item.element.route == key else {
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

        host.unwind(keepingFirst: value.offset + 1, animated: true)
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
    
    /// Closes everything the outgoing root had open.
    ///
    /// A root switch ends a flow — signing out, finishing onboarding — and the screens on
    /// top belonged to it. They used to be left exactly where they were: the root
    /// underneath changed while the user went on looking at screens from the flow that
    /// had just ended, and the coordinator's records went on describing them, so every
    /// later pop was computed against screens that should no longer have existed.
    ///
    /// Not animated. The root change is the visual event; animating the screens away as
    /// well interleaves two transitions to say one thing.
    private func unwindForRootSwitch() {
        host.reconcile()
        host.unwind(keepingFirst: 0, animated: false)
    }

    @discardableResult private func _root<Output: Coordinatable, Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>,
        input: Input? = nil,
        animation: Animation? = nil
    ) -> Output {
        let output: Output = _createRouteOutput(route, input: input)
        unwindForRootSwitch()
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
        unwindForRootSwitch()
        let newItem = NavigationRootItem(keyPath: route.hashValue, input: input, child: AnyView(output))
        let rootSwitch = self[keyPath: route].type
        stack.root.updateItem(newItem, animation: animation, transition: rootSwitch.transition, zOrder: rootSwitch.zOrder)
        return self
    }

    @discardableResult private func _root<Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Screen>>,
        input: Input? = nil,
        animation: Animation? = nil
    ) -> Self {
        let output: Screen = _createRouteOutput(route, input: input)
        unwindForRootSwitch()
        let newItem = NavigationRootItem(keyPath: route.hashValue, input: input, child: output)
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
    
    /// Returns the active root's child if the given route is the one currently rooted.
    ///
    /// Use this to act on the root coordinator without assuming it is active — e.g. a
    /// deep link that only makes sense once the user is authenticated:
    ///
    ///     if let authenticated = hasRoot(\.authenticated)?.unwrap(AuthenticatedCoordinator.self) {
    ///         // ...
    ///     }
    ///
    /// Root coordinator routes are erased to `AnyCoordinator`, so call
    /// `unwrap(_:)` to get back to your own coordinator's API.
    ///
    /// - Returns: The active root's child, or `nil` if a different route is rooted.
    func hasRoot<Input, Output: Coordinatable>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Output? {
        guard let item = stack.root?.activeSlot?.item,
              item.keyPath == route.hashValue else { return nil }
        return item.child as? Output
    }

    /// Whether the given view route is the one currently rooted.
    func hasRoot<Input, Output: View>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Output>>
    ) -> Bool {
        stack.root?.activeSlot?.item.keyPath == route.hashValue
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

    // MARK: - View controller roots
    //
    // Declared in the extension rather than added to the protocol: a new requirement
    // would have to be satisfied by every existing conformer, and nothing here needs
    // dynamic dispatch.

    /// Switches to a root that is a plain `UIViewController`.
    @discardableResult func root(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Screen>>
    ) -> Self {
        self._root(route)
    }

    @discardableResult func root<Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Screen>>,
        _ input: Input
    ) -> Self {
        self._root(route, input: input)
    }

    @discardableResult func root(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Void, Screen>>,
        animation: Animation?
    ) -> Self {
        self._root(route, animation: animation)
    }

    @discardableResult func root<Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Screen>>,
        _ input: Input,
        animation: Animation?
    ) -> Self {
        self._root(route, input: input, animation: animation)
    }

    /// Whether the given view controller route is the one currently rooted.
    func hasRoot<Input>(
        _ route: KeyPath<Self, Transition<Self, RootSwitch, Input, Screen>>
    ) -> Bool {
        stack.root?.activeSlot?.item.keyPath == route.hashValue
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
