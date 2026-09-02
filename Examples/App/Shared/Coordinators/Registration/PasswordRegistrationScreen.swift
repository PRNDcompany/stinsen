import Foundation
import SwiftUI
import Stinsen

struct PasswordRegistrationScreen: View {
    private let services: UnauthenticatedServices

    @State private var password: String = ""
    @State private var passwordAgain: String = ""

    private let username: String

    /// Supplied by the coordinator — see `RegistrationCoordinator+Factory`.
    /// Registration finishes the whole flow, so the coordinator dismisses itself.
    private let onRegistered: () -> Void

    var body: some View {
        ScrollView {
            InfoText("Please enter your desired password")
            RoundedTextField("Enter password", text: $password, secure: true)
            RoundedTextField("Enter password again", text: $passwordAgain, secure: true)
            Spacer(minLength: 32)
            RoundedButton("Register", style: .primary) {
                services.userRegistration.register(username: username, password: password) {
                    onRegistered()
                }
            }
        }
        .navigationTitle(with: "Register user")
    }
    
    init(services: UnauthenticatedServices, username: String, onRegistered: @escaping () -> Void) {
        self.services = services
        self.username = username
        self.onRegistered = onRegistered
    }
}

struct PasswordRegistrationScreen_Previews: PreviewProvider {
    static var previews: some View {
        PasswordRegistrationScreen(
            services: UnauthenticatedServices(),
            username: "user@example.com",
            onRegistered: {}
        )
    }
}
