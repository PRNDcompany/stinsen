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

struct RootSlot {
    var item: NavigationRootItem
    var transition: AnyTransition = .identity
    var zIndex: Double = 0
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
@MainActor
public class NavigationRoot: ObservableObject {
    var activeSlotIndex: Int = 0

    var activeSlot: RootSlot? {
        slots[safe: activeSlotIndex]
    }

    var slots: [RootSlot]
    var zIndex: Double = 0

    init(item: NavigationRootItem, transition: AnyTransition = .identity) {
        let slot = RootSlot(item: item, transition: transition, zIndex: zIndex)
        self.slots = [slot]
    }

    func updateItem(
        _ newItem: NavigationRootItem,
        animation: Animation?,
        transition: AnyTransition,
        zOrder: RootLayer
    ) {
        if let animation {
            withAnimation(animation) {
                activeSlotIndex = prepareSlotIndex(for: newItem, transition: transition, zOrder: zOrder)
                objectWillChange.send()
            }
        } else {
            slots[activeSlotIndex] = RootSlot(item: newItem, transition: transition, zIndex: zIndex)
            objectWillChange.send()
        }
    }

    private func prepareSlotIndex(for item: NavigationRootItem, transition: AnyTransition, zOrder: RootLayer) -> Int {
        let slotIndex = 1 - activeSlotIndex
        zIndex += zOrder == .front ? 1 : -1
        setSlot(
            at: slotIndex,
            RootSlot(item: item, transition: transition, zIndex: zIndex)
        )
        return slotIndex
    }


    private func setSlot(at index: Int, _ slot: RootSlot) {
        if index < slots.count {
            slots[index] = slot
        } else {
            slots.append(slot)
        }
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
