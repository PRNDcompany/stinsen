//
//  LifecycleObserver.swift
//  Stinsen
//
//  Observes and manages view lifecycle events
//

import Foundation

/// Observes lifecycle events for coordinators and views
final class LifecycleObserver<T: NavigationCoordinatable> {
    private let id: Int
    private weak var coordinator: T?
    
    // Lifecycle event callbacks
    var onAppear: (() -> Void)?
    var onDisappear: (() -> Void)?
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        
        setupLifecycleCallbacks()
    }
    
    private func setupLifecycleCallbacks() {
        onAppear = { [weak self] in
            guard let self = self else { return }
            self.coordinator?.appear(self.id)
        }
        
        onDisappear = { [weak self] in
            guard let self = self else { return }
            self.coordinator?.disappear(self.id)
        }
    }
    
    func notifyAppear() {
        onAppear?()
    }
    
    func notifyDisappear() {
        onDisappear?()
    }
}