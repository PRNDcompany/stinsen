import Foundation
import SwiftUI

import Stinsen

struct LoginScreen: View {
    private let services: UnauthenticatedServices

    /// Supplied by the coordinator — see `UnauthenticatedCoordinator+Factory`.
    private let onRegister: () -> Void
    private let onForgotPassword: () -> Void

    @State private var username: String = "user@example.com"
    @State private var password: String = "password"

    var body: some View {
        ScrollView {
            InfoText("Welcome to StinsenApp. This app's purpose is to showcase many of the features Stinsen has to offer. Feel free to look around!")
            VStack {
                Spacer(minLength: 16)
                RoundedTextField("Username", text: $username)
                RoundedTextField("Password", text: $password, secure: true)
                Spacer(minLength: 32)
                RoundedButton("Login") {
                    services.login.login(
                        username: username,
                        password: password,
                        callback: nil
                    )
                }
                RoundedButton("Register", style: .secondary) {
                    onRegister()
                }
                RoundedButton("Forgot your password?", style: .tertiary) {
                    onForgotPassword()
                }
            }
        }
        .navigationTitle(with: "Welcome")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    init(
        services: UnauthenticatedServices,
        onRegister: @escaping () -> Void,
        onForgotPassword: @escaping () -> Void
    ) {
        self.services = services
        self.onRegister = onRegister
        self.onForgotPassword = onForgotPassword
    }
}

struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        LoginScreen(services: UnauthenticatedServices(), onRegister: {}, onForgotPassword: {})
    }
}
