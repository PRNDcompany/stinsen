import Foundation
import SwiftUI
import Stinsen

extension RegistrationCoordinator {
    @ViewBuilder func makeStart() -> some View {
        UserRegistrationScreen { [weak self] username in
            self?.route(to: \.password, username)
        }
    }
    
    @ViewBuilder func makePassword(username: String) -> some View {
        PasswordRegistrationScreen(services: services, username: username) { [weak self] in
            self?.dismissCoordinator()
        }
    }
}
