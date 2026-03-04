import Foundation
import SwiftUI
import UIKit

/// Facade that coordinates stack management and presentation control.
/// Delegates to StackManager (observation) and PresentationController (UIKit presentation).
@MainActor
final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    private weak var coordinator: T?
    
    // Specialized components
    private let stackManager: NavigationStackObserver<T>
    private let presentationController: PresentationController<T>
    
    func setupViewController(_ viewController: UIViewController) {
        // Delegate to presentation controller
        presentationController.setupViewController(viewController)
    }

    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        
        // Initialize components
        self.stackManager = NavigationStackObserver(id: id, coordinator: coordinator, stack: coordinator.stack)
        self.presentationController = PresentationController(id: id, coordinator: coordinator)
        
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
}
