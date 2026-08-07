import Foundation
import SwiftUI
import Stinsen

struct UserRegistrationScreen: View {
    @State private var text: String = ""

    /// Supplied by the coordinator — see `RegistrationCoordinator+Factory`.
    private let onNext: (String) -> Void

    @ViewBuilder var body: some View {
        ScrollView {
            InfoText("Please enter your desired username")
            RoundedTextField("Desired username", text: $text)
            Spacer(minLength: 32)
            RoundedButton("Next step", style: .primary) {
                onNext(text)
            }
        }
        .navigationTitle(with: "Register user")
    }

    init(onNext: @escaping (String) -> Void) {
        self.onNext = onNext
    }
}

struct UserRegistrationScreen_Previews: PreviewProvider {
    static var previews: some View {
        UserRegistrationScreen(onNext: { _ in })
    }
}

