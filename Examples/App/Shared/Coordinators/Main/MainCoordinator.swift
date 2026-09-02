import Foundation
import Combine
import SwiftUI

import Stinsen

@MainActor
final class MainCoordinator: NavigationCoordinatable {
    var stack: Stinsen.NavigationStack<MainCoordinator>
    private var authenticationSubscription: AnyCancellable?

    @Root var unauthenticated = makeUnauthenticated
    @Root var authenticated = makeAuthenticated
    
    @ViewBuilder func sharedView(_ view: AnyView) -> some View {
        view
    }
    
    @ViewBuilder func customize(_ view: AnyView) -> some View {
        #if targetEnvironment(macCatalyst)
            sharedView(view)
        #elseif os(macOS)
            sharedView(view)
        #elseif os(watchOS)
            sharedView(view)
        #elseif os(tvOS)
            sharedView(view)
        #elseif os(iOS)
            if #available(iOS 14.0, *) {
                sharedView(view).onOpenURL(perform: handle).accentColor(Color("AccentColor"))
            } else {
                sharedView(view).accentColor(Color("AccentColor"))
            }
        #else
            sharedView(view)
        #endif
    }
    
    deinit {
        print("Deinit MainCoordinator")
    }

    init() {
        switch AuthenticationService.shared.status {
        case .authenticated(let user):
            stack = NavigationStack(initial: \MainCoordinator.authenticated, user)
        case .unauthenticated:
            stack = NavigationStack(initial: \MainCoordinator.unauthenticated)
        }

        // Coordination state belongs to the coordinator, not to a SwiftUI modifier. This
        // keeps authentication switching alive for both `view()` and the native UIKit
        // `viewController()` entry, including when the active root is another coordinator
        // and therefore has its own UIKit container.
        authenticationSubscription = AuthenticationService.shared.$status
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .unauthenticated:
                    self.root(\.unauthenticated)
                case .authenticated(let user):
                    self.root(\.authenticated, user)
                }
            }
    }

    func handle(_ url: URL) {
        // Root coordinator routes are erased to AnyCoordinator so that factories can
        // return `some Coordinatable`; unwrap to get back to the concrete API.
        guard let coordinator = hasRoot(\.authenticated)?
            .unwrap(AuthenticatedCoordinator.self) else { return }

        do {
            switch try DeepLink(url: url, todosStore: coordinator.todosStore) {
            case .todo(let id):
                coordinator
                    .focusFirst(\.todos)
                    .child
                    .route(to: \.todo, id)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
