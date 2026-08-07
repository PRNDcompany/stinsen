import Foundation
import SwiftUI
import Stinsen

struct TodosScreen: View {
    @ObservedObject private var todosStore: TodosStore

    /// Supplied by the coordinator — see `TodosCoordinator+Factory`.
    private let onCreateTodo: () -> Void
    private let onSelectTodo: (UUID) -> Void

    @ViewBuilder var button: some View {
        Button(action: {
            onCreateTodo()
        }, label: {
            Image(systemName: "folder.badge.plus")
        })
    }
    
    @ViewBuilder var content: some View {
        ScrollView {
            #if !os(iOS)
            button
            #endif
            if todosStore.all.isEmpty {
                InfoText("You have no stored todos.")
            }
            VStack {
                ForEach(todosStore.all) { todo in
                    Button(todo.name, action: {
                        onSelectTodo(todo.id)
                    })
                }
            }
            .padding(18)
        }
        .navigationTitle(with: "Todos")
    }
    
    @ViewBuilder var body: some View {
        #if os(iOS)
        content
        .navigationBarItems(
            trailing: button
        )
        #else
        content
        #endif
    }
    
    init(
        todosStore: TodosStore,
        onCreateTodo: @escaping () -> Void,
        onSelectTodo: @escaping (UUID) -> Void
    ) {
        self.todosStore = todosStore
        self.onCreateTodo = onCreateTodo
        self.onSelectTodo = onSelectTodo
    }
}

struct TodosScreen_Previews: PreviewProvider {
    static var previews: some View {
        TodosScreen(
            todosStore: TodosStore(user: User(username: "user@example.com", accessToken: UUID().uuidString)),
            onCreateTodo: {},
            onSelectTodo: { _ in }
        )
    }
}
