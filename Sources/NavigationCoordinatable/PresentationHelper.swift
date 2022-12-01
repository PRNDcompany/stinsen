import Foundation
import Combine
import SwiftUI

final class PresentationHelper<T: NavigationCoordinatable>: ObservableObject {
    private let id: Int
    let navigationStack: NavigationStack<T>
    private var cancellables = Set<AnyCancellable>()
    
    @Published var presented: Presented?
    
    func setupPresented(coordinator: T, stackValue: [NavigationStackItem]) {
        let value = stackValue
        let nextId = id + 1
        
        // Only apply updates on last screen in navigation stack
        // This check is important to get the behaviour as using a bool-state in the view that you set
        if value.count - 1 == nextId, presented == nil {
            if let value = value[safe: nextId] {
                let presentable = value.presentable
                presented = value.presentationType
                    .makePresented(presentable: presentable, nextId: nextId, coordinator: coordinator)
            }
        }
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.navigationStack = coordinator.stack
        
        setupPresented(coordinator: coordinator, stackValue: coordinator.stack.value)
        
        navigationStack.$value.dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, coordinator] items in
                self?.setupPresented(coordinator: coordinator, stackValue: items)
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
