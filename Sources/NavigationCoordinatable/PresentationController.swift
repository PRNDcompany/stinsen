//
//  PresentationController.swift
//  Stinsen
//
//  Controls UI presentation logic
//

import Foundation
import SwiftUI
import UIKit

/// Controls the presentation of views and coordinators
@MainActor
final class PresentationController<T: NavigationCoordinatable> {
    private let id: Int
    private weak var coordinator: T?
    
    private weak var currentViewController: UIViewController?
    private var currentPresented: ViewControllerPresented?
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
    }
    
    func setupViewController(_ viewController: UIViewController) {
        currentViewController = viewController

        // Register this view controller in the stack
        if let coordinator = coordinator,
           id >= 0 && id < coordinator.stack.value.count {
            // Link the view controller to the corresponding stack item
            var updatedStack = coordinator.stack.value
            updatedStack[id].viewController = viewController
            coordinator.stack.setStack(updatedStack)
        }

        // Present if we have something waiting
        if let presented = currentPresented {
            presentViewIfNeeded(presented)
        }
    }
    
    func present(item: NavigationStackItem) {
        // Check if already presenting
        guard currentPresented == nil else { return }
        
        guard let coordinator = coordinator,
              let presented = item.presentationType.makePresented(
                content: item.content,
                nextId: id + 1,
                coordinator: coordinator
              ) else {
            return
        }
        
        currentPresented = presented
        presentViewIfNeeded(presented)
    }
    
    func dismiss() {
        if let presented = currentPresented {
            presented.dismiss()
        }
        currentPresented = nil
    }
    
    private func presentViewIfNeeded(_ presented: ViewControllerPresented) {
        guard let parent = currentViewController else { return }

        presented.present(
            parent: parent,
            onAppear: { [weak self] in
                let appearId = self?.id ?? 0
                self?.coordinator?.appear(appearId)
            },
            onDisappear: { [weak self] in
                let disappearId = self?.id ?? 0
                self?.currentPresented = nil
                self?.coordinator?.disappear(disappearId)
            }
        )
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
        // VC is now retained by the view hierarchy, release strong reference
        self.releaseStrongReference()
    }
}
