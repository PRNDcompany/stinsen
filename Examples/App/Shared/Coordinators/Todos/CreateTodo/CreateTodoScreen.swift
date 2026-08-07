import Foundation
import SwiftUI
import Stinsen

struct CreateTodoScreen: View {
    @State private var text: String = ""
    @ObservedObject private var todosStore: TodosStore

    /// The screen does not know how it is dismissed, only that it is done.
    /// The coordinator supplies this in its factory — see `TodosCoordinator+Factory`.
    private let onCreated: () -> Void

    var body: some View {
        VStack {
            RoundedTextField("Todo name", text: $text)
            RoundedButton("Create") {
                todosStore.all.append(Todo(name: text))
                onCreated()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    init(todosStore: TodosStore, onCreated: @escaping () -> Void) {
        self.todosStore = todosStore
        self.onCreated = onCreated
    }
}

struct CreateTodoScreen_Previews: PreviewProvider {
    static var previews: some View {
        CreateTodoScreen(
            todosStore: TodosStore(user: User(username: "user@example.com", accessToken: UUID().uuidString)),
            onCreated: {}
        )
    }
}
