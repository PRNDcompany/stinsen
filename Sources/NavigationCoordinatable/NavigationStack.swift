import Foundation
import SwiftUI
import Combine

// Wrapper to break retain cycles - holds weak reference to coordinators
class WeakViewPresentable {
    private weak var weakCoordinator: (any Coordinatable)?
    private let strongView: AnyView?
    
    init(_ presentable: ViewPresentable) {
        if let coordinator = presentable as? any Coordinatable {
            self.weakCoordinator = coordinator
            self.strongView = nil
        } else if let view = presentable as? AnyView {
            self.weakCoordinator = nil
            self.strongView = view
        } else {
            // Should not happen, but handle gracefully
            self.weakCoordinator = nil
            self.strongView = nil
        }
    }
    
    var presentable: ViewPresentable? {
        if let coordinator = weakCoordinator {
            return coordinator
        } else if let view = strongView {
            return view
        }
        return nil
    }
}

struct NavigationRootItem {
    let keyPath: Int
    let input: Any?
    private let childWrapper: WeakViewPresentable
    
    var child: ViewPresentable {
        guard let presentable = childWrapper.presentable else {
            assertionFailure("NavigationRootItem: coordinator has been deallocated")
            return AnyView(EmptyView())
        }
        return presentable
    }
    
    init(keyPath: Int, input: Any?, child: ViewPresentable) {
        self.keyPath = keyPath
        self.input = input
        self.childWrapper = WeakViewPresentable(child)
    }
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
@MainActor
public class NavigationRoot: ObservableObject {
    @Published var item: NavigationRootItem
    
    init(item: NavigationRootItem) {
        self.item = item
    }
}

/// Represents a stack of routes
@MainActor
public class NavigationStack<T: NavigationCoordinatable> {
    var dismissalAction: [Int: () -> Void] = [:]
    
    weak var parent: ChildDismissable?
    
    // Combine-based state management
    // NOTE: Using CurrentValueSubject instead of @Published because
    // @Published fires on willSet (before property update), which causes
    // subscribers to see stale values when accessing stack.value directly.
    // CurrentValueSubject with didSet fires AFTER the property is updated.
    private var _value: [NavigationStackItem] = [] {
        didSet {
            valueSubject.send(_value)
        }
    }
    private let valueSubject = CurrentValueSubject<[NavigationStackItem], Never>([])
    private let poppedSubject = PassthroughSubject<Int, Never>()
    private var cancellables = Set<AnyCancellable>()

    let initial: PartialKeyPath<T>
    let initialInput: Any?
    var root: NavigationRoot!

    // Public access to stack items (now reactive)
    var value: [NavigationStackItem] {
        return _value
    }

    // Combine publishers for reactive programming
    var valuePublisher: AnyPublisher<[NavigationStackItem], Never> {
        valueSubject.eraseToAnyPublisher()
    }
    
    var poppedPublisher: AnyPublisher<Int, Never> {
        poppedSubject.eraseToAnyPublisher()
    }

    public init(initial: PartialKeyPath<T>, _ initialInput: Any? = nil) {
        self._value = []
        self.initial = initial
        self.initialInput = initialInput
        self.root = nil
    }
    
    nonisolated deinit {
        // ARC handles property cleanup
    }

    /// Clean up references to break retain cycles
    func cleanup() {
        _value.removeAll()
        cancellables.removeAll()
        dismissalAction.removeAll()
        // Note: We don't set root to nil here because NavigationCoordinatableView might still need it
    }
    
    // MARK: - Setter Methods
    
    /// Push a new item to the stack
    func push(_ item: NavigationStackItem) {
        // Check for duplicate push (same keyPath being pushed consecutively)
        if let lastItem = _value.last, lastItem.keyPath == item.keyPath {
            return
        }

        _value.append(item)
    }
    
    /// Pop to a specific index
    func popToIndex(_ index: Int) {
        guard index >= -1 && index < _value.count else {
            return
        }
        
        // Track coordinators that are being removed for memory leak detection
        #if DEBUG
        let itemsBeingRemoved: [NavigationStackItem]
        if index == -1 {
            itemsBeingRemoved = _value
        } else {
            itemsBeingRemoved = Array(_value.suffix(from: index + 1))
        }
        
        // Track each coordinator being removed
        for item in itemsBeingRemoved {
            if let coordinator = item.presentable as? any Coordinatable {
                coordinator.trackForMemoryLeak()
            }
        }
        #endif
        
        if index == -1 {
            _value = []
        } else {
            _value = Array(_value.prefix(index + 1))
        }
        poppedSubject.send(index)
        // Published property will automatically notify subscribers
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
