import Foundation
import SwiftUI
import Stinsen

extension TodosCoordinator {
    @ViewBuilder func makeTodo(todoId: UUID) -> some View {
        TodoScreen(todosStore: todosStore, todoId: todoId)
    }
    
    @ViewBuilder func makeCreateTodo() -> some View {
        // `[weak self]` matters: the coordinator owns this view through its stack, so a
        // strong capture here would be coordinator → stack → view → coordinator.
        CreateTodoScreen(todosStore: todosStore) { [weak self] in
            self?.popToRoot()
        }
    }
    
    @ViewBuilder func makeStart() -> some View {
        TodosScreen(
            todosStore: todosStore,
            onCreateTodo: { [weak self] in self?.route(to: \.createTodo) },
            onSelectTodo: { [weak self] id in self?.route(to: \.todo, id) }
        )
    }
}
