import Foundation
import SwiftUI

final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    private weak var coordinator: T?
    
    private weak var currentViewController: UIViewController?
    private var currentPresented: Presented?

    func setupViewController(_ viewController: UIViewController) {
        currentViewController = viewController
        
        // Register this view controller in the stack
        #if canImport(UIKit)
        if let coordinator = coordinator,
           id >= 0 && id < coordinator.stack.value.count {
            // Link the view controller to the corresponding stack item
            // This is a bit tricky since NavigationStackItem is a struct
            // We need to update the stack with the new item
            var updatedStack = coordinator.stack.value
            updatedStack[id].viewController = viewController
            coordinator.stack.setStack(updatedStack)
        }
        #endif
        
        // Present if we have something waiting
        if let presented = currentPresented {
            presentViewIfNeeded(presented)
        }
    }

    func handleStackChanged(_ items: [NavigationStackItem]) {
        let nextId = id + 1
        // Only apply updates on last screen in navigation stack
        // This check is important to get the behaviour as using a bool-state in the view that you set
        guard items.count - 1 == nextId,
              currentPresented == nil,
              let item = items[safe: nextId] else { return }

        let presentable = item.presentable
        let presented = item.presentationType.makePresented(
            presentable: presentable,
            nextId: nextId,
            coordinator: coordinator!
        )
        
        currentPresented = presented
        presentViewIfNeeded(presented)
    }
    
    func handlePopped(to index: Int) {
        // Remove presented views if my id is less than or equal to the view being popped to
        if index <= id {
            removePresented()
        }
    }
    
    private func presentViewIfNeeded(_ presented: Presented) {
        guard let parent = currentViewController else { return }
        
        presented.present(
            parent: parent,
            onAppear: { [weak self] in
                self?.coordinator?.appear(self?.id ?? 0)
            },
            onDisappear: { [weak self] in
                self?.coordinator?.disappear(self?.id ?? 0)
            }
        )
    }

    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        let navigationStack = coordinator.stack

        // Set up callbacks
        navigationStack.onStackChanged = { [weak self] items in
            DispatchQueue.main.async {
                self?.handleStackChanged(items)
            }
        }
        
        navigationStack.onPopped = { [weak self] index in
            DispatchQueue.main.async {
                self?.handlePopped(to: index)
            }
        }
        
        // Initial setup
        handleStackChanged(navigationStack.value)
    }

    func removePresented() {
        if case let .viewController(presented) = currentPresented {
            presented.dismiss()
        }
        currentPresented = nil
    }
}


private extension Presented {
    func present(parent: UIViewController, onAppear: @escaping () -> Void, onDisappear: @escaping () -> Void) {
        guard case let .viewController(uiKitPresented) = self,
              let destination = uiKitPresented.viewController else { return }
        uiKitPresented.presentationType.presented(
            parent: parent,
            content: destination,
            onAppeared: onAppear,
            onDissmissed: onDisappear
        )
    }
}
