import Foundation
import SwiftUI
import UIKit
import Combine

struct NavigationRootItem {
    let keyPath: Int
    let input: Any?
    // Strong reference: root coordinator has no retain cycle
    // (parent reference is weak, so Coordinator → Stack → Root → child is safe)
    let child: ViewPresentable

    init(keyPath: Int, input: Any?, child: ViewPresentable) {
        self.keyPath = keyPath
        self.input = input
        self.child = child
    }
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
@MainActor
public class NavigationRoot: ObservableObject {
    @Published var item: NavigationRootItem
    @Published var activeSlot: Int = 0
    // Unified transition (@Published so changing it triggers re-render of the
    // currently-visible slot with the correct transition BEFORE the slot change fires)
    @Published var transition: AnyTransition = .identity
    // Deferred animation trigger: UUID ensures onChange fires even on rapid successive calls
    @Published var pendingTransitionId: UUID? = nil

    // Not @Published: slot content is read during view body evaluation
    // triggered by activeSlot/pendingTransitionId changes.
    var slots: [NavigationRootItem?] = [nil, nil]
    var slotZIndex: [Double] = [0, 0]
    var zIndex: Double = 0

    // Pending state read by view's onChange handler
    var pendingAnimation: Animation? = nil
    var pendingSlot: Int = 0
    var pendingItem: NavigationRootItem? = nil

    init(item: NavigationRootItem) {
        self.item = item
        self.slots[0] = item
    }

    func updateItem(_ newItem: NavigationRootItem, animation: Animation?,
                    transition: AnyTransition) {
        if let animation {
            // Two-phase animated transition:
            // Phase 1 (this call): update transition (@Published) → re-render the
            //   currently-visible slot with correct transition while it's still on screen.
            // Phase 2 (onChange in view): withAnimation { activeSlot = newSlot } fires
            //   after re-render, so SwiftUI uses the freshly-rendered transition for removal.
            let oldSlot = activeSlot
            let newSlot = 1 - activeSlot

            slotZIndex[newSlot] = zIndex
            zIndex += 1
            slotZIndex[oldSlot] = zIndex

            slots[newSlot] = newItem
            pendingAnimation = animation
            pendingSlot = newSlot
            pendingItem = newItem

            // @Published changes: batched into one re-render (Phase 1)
            self.transition = transition
            pendingTransitionId = UUID()
        } else {
            // Non-animated: update current slot content in-place
            slots[activeSlot] = newItem
            self.item = newItem
        }
    }

    /// Commits the pending animated transition.
    /// In production this is called by the view's onChange handler (with withAnimation).
    /// In unit tests this is called directly to simulate the view lifecycle.
    func commitTransition() {
        guard let newItem = pendingItem else { return }
        activeSlot = pendingSlot
        item = newItem
        pendingTransitionId = nil
        pendingItem = nil
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
            if case .coordinator(let coordinator) = item.content {
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

/// Preserves compile-time type information from route methods.
/// Route methods know whether Output is View or Coordinatable via generics —
/// this enum carries that distinction through the stack instead of erasing it to ViewPresentable.
@MainActor
public enum StackItemContent {
    case view(AnyView)
    case coordinator(any Coordinatable)
}

struct NavigationStackItem {
    let presentationType: PresentationType
    let content: StackItemContent
    let keyPath: Int
    let input: Any?

    // Store weak reference using WeakRef wrapper
    var viewControllerRef: WeakRef<UIViewController>?

    var viewController: UIViewController? {
        get { viewControllerRef?.value }
        set { viewControllerRef = newValue.map { WeakRef(value: $0) } }
    }

    init(presentationType: PresentationType,
         content: StackItemContent,
         keyPath: Int,
         input: Any?,
         viewController: UIViewController? = nil) {
        self.presentationType = presentationType
        self.content = content
        self.keyPath = keyPath
        self.input = input
        self.viewControllerRef = viewController.map { WeakRef(value: $0) }
    }
}
