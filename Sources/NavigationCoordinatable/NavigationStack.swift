import Foundation
import SwiftUI

struct NavigationRootItem {
    let keyPath: Int
    let input: Any?
    let child: ViewPresentable
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
public class NavigationRoot: ObservableObject {
    @Published var item: NavigationRootItem
    
    init(item: NavigationRootItem) {
        self.item = item
    }
}

/// Represents a stack of routes
public class NavigationStack<T: NavigationCoordinatable> {
    var dismissalAction: [Int: () -> Void] = [:]
    
    weak var parent: ChildDismissable?
    
    // Direct callback instead of Combine
    var onStackChanged: (([NavigationStackItem]) -> Void)?
    var onPopped: ((Int) -> Void)?

    let initial: PartialKeyPath<T>
    let initialInput: Any?
    var root: NavigationRoot!

    // Private storage for stack items
    private var _value: [NavigationStackItem] = []
    
    // Read-only public access
    var value: [NavigationStackItem] {
        return _value
    }

    public init(initial: PartialKeyPath<T>, _ initialInput: Any? = nil) {
        self._value = []
        self.initial = initial
        self.initialInput = initialInput
        self.root = nil
    }
    
    // MARK: - Setter Methods
    
    /// Push a new item to the stack
    func push(_ item: NavigationStackItem) {
        _value.append(item)
        onStackChanged?(_value)
    }
    
    /// Pop to a specific index
    func popToIndex(_ index: Int) {
        guard index >= -1 && index < _value.count else { return }
        
        if index == -1 {
            _value = []
        } else {
            _value = Array(_value.prefix(index + 1))
        }
        
        onPopped?(index)
        onStackChanged?(_value)
    }
    
    #if canImport(UIKit)
    /// Pop to a specific view controller
    func popToViewController(_ viewController: UIViewController) {
        if let index = _value.firstIndex(where: { $0.viewController === viewController }) {
            popToIndex(index)
        }
    }
    
    /// Find the index of a view controller in the stack
    func indexOfViewController(_ viewController: UIViewController) -> Int? {
        return _value.firstIndex(where: { $0.viewController === viewController })
    }
    #endif
    
    /// Replace the entire stack
    func setStack(_ newValue: [NavigationStackItem]) {
        _value = newValue
        onStackChanged?(_value)
    }
}

/// Convenience checks against the navigation stack's contents
public extension NavigationStack {
    /**
        The Hash of the route at the top of the stack
        - Returns: the hash of the route at the top of the stack or -1
     */
    var currentRoute: Int {
        return value.last?.keyPath ?? -1
    }

    /**
    Checks if a particular KeyPath is in a stack
     - Parameter keyPathHash:The hash of the keyPath
     - Returns: Boolean indiacting whether the route is in the stack
     */
    func isInStack(_ keyPathHash: Int) -> Bool {
        return value.contains { $0.keyPath == keyPathHash }
    }
}

struct NavigationStackItem {
    let presentationType: PresentationType
    let presentable: ViewPresentable
    let keyPath: Int
    let input: Any?
    
    #if canImport(UIKit)
    // Store weak reference using WeakRef wrapper
    var viewControllerRef: WeakRef<UIViewController>?
    
    var viewController: UIViewController? {
        get { viewControllerRef?.value }
        set { viewControllerRef = newValue.map { WeakRef(value: $0) } }
    }
    
    init(presentationType: PresentationType, 
         presentable: ViewPresentable,
         keyPath: Int,
         input: Any?,
         viewController: UIViewController? = nil) {
        self.presentationType = presentationType
        self.presentable = presentable
        self.keyPath = keyPath
        self.input = input
        self.viewControllerRef = viewController.map { WeakRef(value: $0) }
    }
    #else
    init(presentationType: PresentationType,
         presentable: ViewPresentable,
         keyPath: Int,
         input: Any?) {
        self.presentationType = presentationType
        self.presentable = presentable
        self.keyPath = keyPath
        self.input = input
    }
    #endif
}
