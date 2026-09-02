import Foundation
import SwiftUI
import Stinsen

extension UnauthenticatedCoordinator {
    func makeRegistration() -> RegistrationCoordinator {
        return RegistrationCoordinator(services: unauthenticatedServices)
    }
    
    @ViewBuilder func makeForgotPassword() -> some View {
        ForgotPasswordScreen(services: unauthenticatedServices) { [weak self] in
            self?.popToRoot()
        }
    }
    
    @ViewBuilder func makeStart() -> some View {
        LoginScreen(
            services: unauthenticatedServices,
            onRegister: { [weak self] in self?.route(to: \.registration) },
            onForgotPassword: { [weak self] in self?.route(to: \.forgotPassword) }
        )
    }
}
