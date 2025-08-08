import Foundation
import SwiftUI

final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    private weak var coordinator: T?
    
    #if canImport(UIKit)
    private weak var currentViewController: UIViewController?
    #endif
    private var currentPresented: ViewControllerPresented?
    
    deinit {
        // Important: Clean up any remaining presented views
        if currentPresented != nil {
            removePresented()
        }
    }

    #if canImport(UIKit)
    func setupViewController(_ viewController: UIViewController) {
        currentViewController = viewController
        
        // Register this view controller in the stack
        if let coordinator = coordinator,
           id >= 0 && id < coordinator.stack.value.count {
            // Link the view controller to the corresponding stack item
            // This is a bit tricky since NavigationStackItem is a struct
            // We need to update the stack with the new item
            var updatedStack = coordinator.stack.value
            updatedStack[id].viewController = viewController
            coordinator.stack.setStack(updatedStack)
        }
        
        // Present if we have something waiting
        if let presented = currentPresented {
            presentViewIfNeeded(presented)
        }
    }
    #else
    func setupViewController(_ viewController: Any) {
        // Non-UIKit platforms don't use this
    }
    #endif

    func handleStackChanged(_ items: [NavigationStackItem]) {
        // Only root coordinator should handle stack changes
        guard id == -1 else {
            return
        }
        
        let nextId = id + 1  // For root, nextId = 0
        
        // Root coordinator handles the first item (index 0) when stack has exactly 1 item
        guard items.count == 1 else {
            return
        }
        
        // Check if already presenting
        guard currentPresented == nil else {
            return
        }
        
        guard let item = items[safe: nextId] else {
            return
        }

        let presentable = item.presentable
        guard let presented = item.presentationType.makePresented(
            presentable: presentable,
            nextId: nextId,
            coordinator: coordinator!
        ) else {
            return
        }
        
        currentPresented = presented
        presentViewIfNeeded(presented)
    }
    
    func handlePopped(to index: Int) {
        // Remove presented views if my id is less than or equal to the view being popped to
        if index <= id {
            removePresented()
        }
    }
    
    // Add method to handle dismiss from external source (like UIKitPresentation)
    func handleDismissed() {
        currentPresented = nil
    }
    
    private func presentViewIfNeeded(_ presented: ViewControllerPresented) {
        #if canImport(UIKit)
        guard let parent = currentViewController else {
            return
        }
        
        presented.present(
            parent: parent,
            onAppear: { [weak self] in
                let appearId = self?.id ?? 0
                self?.coordinator?.appear(appearId)
            },
            onDisappear: { [weak self] in
                let disappearId = self?.id ?? 0
                // Clear currentPresented when dismissed
                self?.currentPresented = nil
                self?.coordinator?.disappear(disappearId)
            }
        )
        #endif
    }

    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        let navigationStack = coordinator.stack
        
        // IMPORTANT: Only root PresentationHelper (id = -1) should manage navigation
        // This prevents multiple PresentationHelpers from conflicting
        if id == -1 {
            
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
    }

    func removePresented() {
        #if canImport(UIKit)
        if let presented = currentPresented {
            presented.dismiss()
        }
        #endif
        currentPresented = nil
    }
}


#if canImport(UIKit)
private extension ViewControllerPresented {
    func present(parent: UIViewController, onAppear: @escaping () -> Void, onDisappear: @escaping () -> Void) {
        guard let destination = self.viewController else { return }
        self.presentationType.presented(
            parent: parent,
            content: destination,
            onAppeared: onAppear,
            onDismissed: onDisappear
        )
    }
}
#endif
