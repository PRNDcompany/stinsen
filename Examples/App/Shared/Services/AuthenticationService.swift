import Foundation

class AuthenticationService: ObservableObject {
    enum Status: Equatable {
        case authenticated(User)
        case unauthenticated
    }
    
    static var shared: AuthenticationService = AuthenticationService()
    
    @Published var status: Status {
        didSet {
            switch status {
            case .unauthenticated:
                UserDefaults.standard.removeObject(forKey: "user")
            case .authenticated(let user):
                let encoder = JSONEncoder()
                let jsonString = try! encoder.encode(user)
                UserDefaults.standard.setValue(jsonString, forKey: "user")
            }
        }
    }

    /// UI tests need a deterministic starting point. Without this the previous run's
    /// persisted login leaks into the next one and tests pass or fail depending on
    /// what ran before them.
    ///
    /// `--uitesting`               → always start logged out
    /// `--uitesting-authenticated` → always start logged in as a fixed user
    private enum LaunchOverride {
        static var arguments: [String] { ProcessInfo.processInfo.arguments }
        static var isUITesting: Bool { arguments.contains("--uitesting") || startsAuthenticated }
        static var startsAuthenticated: Bool { arguments.contains("--uitesting-authenticated") }
    }

    init() {
        if LaunchOverride.isUITesting {
            UserDefaults.standard.removeObject(forKey: "user")
            self.status = LaunchOverride.startsAuthenticated
                ? .authenticated(User(username: "uitest@example.com", accessToken: "uitest"))
                : .unauthenticated
            return
        }

        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "user"),
           let user = try? decoder.decode(User.self, from: data) {
            self.status = .authenticated(user)
        } else {
            self.status = .unauthenticated
        }
    }
}
