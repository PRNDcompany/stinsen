//
//  NavigationStackObserver.swift
//  Stinsen
//
//  Observes navigation stack changes via Combine and triggers presentation callbacks
//

import Foundation
import Combine

/// Observes NavigationStack changes via Combine subscriptions and
/// triggers presentation/dismissal callbacks when the stack mutates.
@MainActor
final class NavigationStackObserver<T: NavigationCoordinatable> {
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
}

@available(*, deprecated, renamed: "NavigationStackObserver")
typealias StackManager = NavigationStackObserver