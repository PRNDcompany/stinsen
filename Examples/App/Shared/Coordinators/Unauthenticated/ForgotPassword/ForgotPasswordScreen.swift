import Foundation
import SwiftUI

import Stinsen

struct ForgotPasswordScreen: View {
    @State private var text: String = ""
    private var services: UnauthenticatedServices

    /// Supplied by the coordinator — see `UnauthenticatedCoordinator+Factory`.
    private let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack {
                InfoText("Forgot your password? No problem! Just enter your username below and we will send it to you (actually, we won't, this is just to showcase how to navigate back in a flow).")
                Spacer(minLength: 16)
                RoundedTextField("Username", text: $text)
                Spacer(minLength: 32)
                RoundedButton("OK") {
                    services.forgotPassword.forgot(username: text) {
                        onDone()
                    }
                }
            }
            .navigationTitle(with: "Forgot password")
        }
    }
    
    init(services: UnauthenticatedServices, onDone: @escaping () -> Void) {
        self.services = services
        self.onDone = onDone
    }
}

struct ForgotPasswordScreen_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordScreen(services: UnauthenticatedServices(), onDone: {})
    }
}
