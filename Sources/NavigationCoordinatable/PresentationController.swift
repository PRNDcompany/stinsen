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
        guard currentPresented == nil,
              let coordinator = coordinator else {
            return
        }

        // Removal notification is born here — the owner of currentPresented/disappear —
        // and injected at creation time so detection is wired where the VC is made.
        // One-shot semantics live in the observer: it discards this closure after firing.
        let onRemoved: () -> Void = { [weak self, weak coordinator, id] in
            // FIXME: 검증용 로그 — 검증 완료 후 제거
            print("🔬 [RemovalLedger] onDismissed 발화")
            self?.currentPresented = nil
            coordinator?.disappear(id)
        }

        guard let presented = item.presentationType.makePresented(
            content: item.content,
            nextId: id + 1,
            coordinator: coordinator,
            onRemoved: onRemoved
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
            parent: parent
        )
    }
    
}

private extension ViewControllerPresented {
    func present(parent: UIViewController) {
        guard let destination = self.viewController else { return }
        self.presentationType.presented(
            parent: parent,
            content: destination
        )
        // VC is now retained by the view hierarchy, release strong reference
        self.releaseStrongReference()
    }
}
