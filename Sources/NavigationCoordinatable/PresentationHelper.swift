import Foundation
import SwiftUI

/// Facade that coordinates stack management, presentation control, and lifecycle observation
/// This is a thin wrapper that delegates to specialized components for better separation of concerns
final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    private weak var coordinator: T?
    
    // Specialized components
    private let stackManager: StackManager<T>
    private let presentationController: PresentationController<T>
    private let lifecycleObserver: LifecycleObserver<T>
    
    #if canImport(UIKit)
    // Maintained for backward compatibility
    private var currentViewController: UIViewController? {
        // Access through presentation controller
        return nil
    }
    #endif
    
    // Maintained for backward compatibility
    private var currentPresented: ViewControllerPresented? {
        // Access through presentation controller
        return nil
    }
    
    deinit {
        // Presentation controller handles cleanup
        presentationController.dismiss()
    }

    #if canImport(UIKit)
    func setupViewController(_ viewController: UIViewController) {
        // Delegate to presentation controller
        presentationController.setupViewController(viewController)
    }
    #else
    func setupViewController(_ viewController: Any) {
        // Non-UIKit platforms don't use this
        presentationController.setupViewController(viewController)
    }
    #endif

    func handleStackChanged(_ items: [NavigationStackItem]) {
        // StackManager handles this internally now through Combine
        // This method is kept for backward compatibility but does nothing
    }
    
    func handlePopped(to index: Int) {
        // StackManager handles this internally now through Combine
        // This method is kept for backward compatibility but does nothing
    }
    
    // Add method to handle dismiss from external source (like UIKitPresentation)
    func handleDismissed() {
        presentationController.dismiss()
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        
        // Initialize components
        self.stackManager = StackManager(id: id, coordinator: coordinator, stack: coordinator.stack)
        self.presentationController = PresentationController(id: id, coordinator: coordinator)
        self.lifecycleObserver = LifecycleObserver(id: id, coordinator: coordinator)
        
        // Wire up components
        setupComponentConnections()
    }
    
    private func setupComponentConnections() {
        // Connect stack manager to presentation controller
        stackManager.onPresentationNeeded = { [weak self] item in
            self?.presentationController.present(item: item)
        }
        
        stackManager.onDismissalNeeded = { [weak self] in
            self?.presentationController.dismiss()
        }
    }

    func removePresented() {
        presentationController.dismiss()
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
