//
//  StackManager.swift
//  Stinsen
//
//  Manages navigation stack operations
//

import Foundation
import Combine

/// Manages stack operations and coordinates with NavigationStack
@MainActor
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
        guard let stack = stack else { return }

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
    }

    private func handleStackChanged(_ items: [NavigationStackItem]) {
        let nextId = id + 1

        // Present the item at our level if it exists
        // PresentationController guards against duplicate presentations
        guard items.count > nextId,
              let item = items[safe: nextId] else {
            return
        }

        onPresentationNeeded?(item)
    }
    
    private func handlePopped(to index: Int) {
        // Remove presented views if my id is less than or equal to the view being popped to
        if index <= id {
            onDismissalNeeded?()
        }
    }
    
    nonisolated deinit {
        // ARC handles property cleanup
    }
}