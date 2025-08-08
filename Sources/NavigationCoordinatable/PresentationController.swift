//
//  PresentationController.swift
//  Stinsen
//
//  Controls UI presentation logic
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Controls the presentation of views and coordinators
final class PresentationController<T: NavigationCoordinatable> {
    private let id: Int
    private weak var coordinator: T?
    
    #if canImport(UIKit)
    private weak var currentViewController: UIViewController?
    #endif
    private var currentPresented: ViewControllerPresented?
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
    }
    
    #if canImport(UIKit)
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
    #else
    func setupViewController(_ viewController: Any) {
        // Non-UIKit platforms don't use this
    }
    #endif
    
    func present(item: NavigationStackItem) {
        // Check if already presenting
        guard currentPresented == nil else { return }
        
        let presentable = item.presentable
        guard let coordinator = coordinator,
              let presented = item.presentationType.makePresented(
                presentable: presentable,
                nextId: id + 1,
                coordinator: coordinator
              ) else {
            return
        }
        
        currentPresented = presented
        presentViewIfNeeded(presented)
    }
    
    func dismiss() {
        #if canImport(UIKit)
        if let presented = currentPresented {
            presented.dismiss()
        }
        #endif
        currentPresented = nil
    }
    
    private func presentViewIfNeeded(_ presented: ViewControllerPresented) {
        #if canImport(UIKit)
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
        #endif
    }
    
    deinit {
        // Clean up any remaining presented views
        if currentPresented != nil {
            dismiss()
        }
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