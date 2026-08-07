import Foundation
import SwiftUI

import Stinsen

final class MainCoordinator: NavigationCoordinatable {
    var stack: Stinsen.NavigationStack<MainCoordinator>

    @Root var unauthenticated = makeUnauthenticated
    @Root var authenticated = makeAuthenticated
    
    @ViewBuilder func sharedView(_ view: AnyView) -> some View {
        view
            .onReceive(AuthenticationService.shared.$status, perform: { status in
                switch status {
                case .unauthenticated:
                    self.root(\.unauthenticated)
                case .authenticated(let user):
                    self.root(\.authenticated, user)
                }
            })
            
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
                sharedView(view).onOpenURL(perform: { url in
                    // Root coordinator routes are erased to AnyCoordinator so that
                    // factories can return `some Coordinatable`; unwrap to get back to
                    // AuthenticatedCoordinator's own API (todosStore, focusFirst).
                    if let coordinator = self.hasRoot(\.authenticated)?
                        .unwrap(AuthenticatedCoordinator.self) {
                        do {
                            let deepLink = try DeepLink(url: url, todosStore: coordinator.todosStore)
                            
                            switch deepLink {
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
                }).accentColor(Color("AccentColor"))
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
    }
}
