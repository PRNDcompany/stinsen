import Foundation
import Combine
import SwiftUI

final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    private var cancellables = Set<AnyCancellable>()
    
    @Published var presented: Presented?
    
    func setupPresented(coordinator: T, value: [NavigationStackItem]) {
        let nextId = id + 1
        
        // Only apply updates on last screen in navigation stack
        // This check is important to get the behaviour as using a bool-state in the view that you set
        guard value.count - 1 == nextId, presented == nil, let value = value[safe: nextId] else { return }
        
        let presentable = value.presentable
        presented = value.presentationType.makePresented(
            presentable: presentable,
            nextId: nextId,
            coordinator: coordinator
        )
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        let navigationStack = coordinator.stack
        
        setupPresented(coordinator: coordinator, value: navigationStack.value)
        
        navigationStack.$value
            .receive(on: DispatchQueue.main)
            .sink { [weak self, coordinator] items in
                self?.setupPresented(coordinator: coordinator, value: items)
            }
            .store(in: &cancellables)
        
        navigationStack.poppedTo.filter { int -> Bool in int <= id }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] int in
                // remove any and all presented views if my id is less than or equal to the view being popped to!
                self?.removePresented()

            }
            .store(in: &cancellables)
    }

    func removePresented() {
        if case let .viewController(presented) = presented {
            presented.dismiss()
        }
        presented = nil
    }
}
