import Foundation
import SwiftUI

final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    private weak var coordinator: T?
    
    private weak var currentViewController: UIViewController?
    private var currentPresented: ViewControllerPresented?
    
    deinit {
        print("[stinsen] PresentationHelper.deinit: id=\(id) being deallocated")
        // Important: Clean up any remaining presented views
        if currentPresented != nil {
            print("[stinsen] PresentationHelper.deinit: Cleaning up currentPresented")
            removePresented()
        }
    }

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
        // Only root coordinator should handle stack changes
        guard id == -1 else {
            print("[stinsen] PresentationHelper.handleStackChanged: Non-root (id=\(id)) - ignoring stack changes")
            return
        }
        
        let nextId = id + 1  // For root, nextId = 0
        print("[stinsen] PresentationHelper.handleStackChanged: Root coordinator handling, items.count=\(items.count)")
        print("[stinsen] PresentationHelper.handleStackChanged: currentPresented=\(currentPresented != nil ? "exists" : "nil")")
        
        // Debug: Print all items in stack
        for (index, item) in items.enumerated() {
            print("[stinsen] PresentationHelper.handleStackChanged:   Stack[\(index)]: keyPath=\(item.keyPath)")
        }
        
        // Root coordinator handles the first item (index 0) when stack has exactly 1 item
        guard items.count == 1 else {
            if items.count > 1 {
                print("[stinsen] PresentationHelper.handleStackChanged: ⚠️ Multiple items in stack (\(items.count)), only handling first push")
            } else {
                print("[stinsen] PresentationHelper.handleStackChanged: ⚠️ Empty stack, nothing to present")
            }
            return
        }
        
        // Check if already presenting
        guard currentPresented == nil else {
            print("[stinsen] PresentationHelper.handleStackChanged: ⚠️ Already presenting, ignoring")
            return
        }
        
        guard let item = items[safe: nextId] else {
            print("[stinsen] PresentationHelper.handleStackChanged: ⚠️ No item at index \(nextId), returning")
            return
        }

        print("[stinsen] PresentationHelper.handleStackChanged: Creating presented for item at index \(nextId)")
        let presentable = item.presentable
        guard let presented = item.presentationType.makePresented(
            presentable: presentable,
            nextId: nextId,
            coordinator: coordinator!
        ) else {
            print("[stinsen] PresentationHelper.handleStackChanged: ⚠️ Failed to create presented")
            return
        }
        
        currentPresented = presented
        print("[stinsen] PresentationHelper.handleStackChanged: ✅ Calling presentViewIfNeeded")
        presentViewIfNeeded(presented)
    }
    
    func handlePopped(to index: Int) {
        print("[stinsen] PresentationHelper.handlePopped: to index=\(index), my id=\(id)")
        // Remove presented views if my id is less than or equal to the view being popped to
        if index <= id {
            print("[stinsen] PresentationHelper.handlePopped: Removing presented (index \(index) <= id \(id))")
            removePresented()
        } else {
            print("[stinsen] PresentationHelper.handlePopped: Not removing (index \(index) > id \(id))")
        }
    }
    
    // Add method to handle dismiss from external source (like UIKitPresentation)
    func handleDismissed() {
        print("[stinsen] PresentationHelper.handleDismissed: Clearing currentPresented")
        currentPresented = nil
    }
    
    private func presentViewIfNeeded(_ presented: ViewControllerPresented) {
        guard let parent = currentViewController else {
            print("[stinsen] PresentationHelper.presentViewIfNeeded: ⚠️ No currentViewController, returning")
            return
        }
        
        print("[stinsen] PresentationHelper.presentViewIfNeeded: Presenting with parent=\(parent)")
        presented.present(
            parent: parent,
            onAppear: { [weak self] in
                let appearId = self?.id ?? 0
                print("[stinsen] PresentationHelper.presentViewIfNeeded.onAppear: id=\(appearId)")
                self?.coordinator?.appear(appearId)
            },
            onDisappear: { [weak self] in
                let disappearId = self?.id ?? 0
                print("[stinsen] PresentationHelper.presentViewIfNeeded.onDisappear: id=\(disappearId)")
                // Clear currentPresented when dismissed
                self?.currentPresented = nil
                print("[stinsen] PresentationHelper.presentViewIfNeeded.onDisappear: currentPresented cleared")
                self?.coordinator?.disappear(disappearId)
            }
        )
        print("[stinsen] PresentationHelper.presentViewIfNeeded: ✅ Present called")
    }

    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        let navigationStack = coordinator.stack
        
        print("[stinsen] PresentationHelper.init: Created with id=\(id), coordinator=\(type(of: coordinator))")

        // IMPORTANT: Only root PresentationHelper (id = -1) should manage navigation
        // This prevents multiple PresentationHelpers from conflicting
        if id == -1 {
            print("[stinsen] PresentationHelper.init: Root coordinator - setting up callbacks")
            
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
        } else {
            print("[stinsen] PresentationHelper.init: Non-root (id=\(id)) - skipping callbacks to prevent conflicts")
        }
    }

    func removePresented() {
        print("[stinsen] PresentationHelper.removePresented: Called")
        if let presented = currentPresented {
            print("[stinsen] PresentationHelper.removePresented: Dismissing viewController")
            presented.dismiss()
        } else {
            print("[stinsen] PresentationHelper.removePresented: No viewController to dismiss")
        }
        currentPresented = nil
        print("[stinsen] PresentationHelper.removePresented: ✅ currentPresented cleared")
    }
}


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
