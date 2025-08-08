//
//  StackManager.swift
//  Stinsen
//
//  Manages navigation stack operations
//

import Foundation
import Combine

/// Manages stack operations and coordinates with NavigationStack
final class StackManager<T: NavigationCoordinatable> {
    private let id: Int
    private weak var coordinator: T?
    private weak var stack: NavigationStack<T>?
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks for presentation events
    var onPresentationNeeded: ((NavigationStackItem) -> Void)?
    var onDismissalNeeded: (() -> Void)?
    
    init(id: Int, coordinator: T, stack: NavigationStack<T>) {
        self.id = id
        self.coordinator = coordinator
        self.stack = stack
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Only root manager (id = -1) handles stack changes
        guard id == -1 else { return }
        
        // Use Combine publishers if available, fallback to callbacks
        if let stack = stack {
            // Subscribe to stack changes
            stack.valuePublisher
                .sink { [weak self] items in
                    self?.handleStackChanged(items)
                }
                .store(in: &cancellables)
            
            // Subscribe to pop events
            stack.poppedPublisher
                .sink { [weak self] index in
                    self?.handlePopped(to: index)
                }
                .store(in: &cancellables)
            
            // Initial setup
            handleStackChanged(stack.value)
        }
    }
    
    private func handleStackChanged(_ items: [NavigationStackItem]) {
        // Only root coordinator should handle stack changes
        guard id == -1 else { return }
        
        let nextId = id + 1  // For root, nextId = 0
        
        // Root coordinator handles the first item (index 0) when stack has exactly 1 item
        guard items.count == 1,
              let item = items[safe: nextId] else {
            return
        }
        
        // Notify about presentation needed
        onPresentationNeeded?(item)
    }
    
    private func handlePopped(to index: Int) {
        // Remove presented views if my id is less than or equal to the view being popped to
        if index <= id {
            onDismissalNeeded?()
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
}