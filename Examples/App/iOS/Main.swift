import Foundation
import UIKit
import SwiftUI

import Stinsen

@main
struct MainApp {
    /// Boots the same coordinator through either runtime's entry point.
    ///
    /// `--uikit-entry` starts from a `SceneDelegate` that sets
    /// `window.rootViewController = MainCoordinator().viewController()`; without it the
    /// app starts from a SwiftUI `App` rendering `MainCoordinator().view()`.
    ///
    /// This exists so the UI tests can run **unchanged** against both. The screens, the
    /// routes and the assertions are identical either way — which is precisely the claim
    /// being made, and it is not one that can be checked by reading the code.
    static func main() {
        let usesUIKitEntry = CommandLine.arguments.contains("--uikit-entry")

        if #available(iOS 14.0, *), !usesUIKitEntry {
            StinsenApp.main()
        } else {
            UIApplicationMain(
                CommandLine.argc,
                CommandLine.unsafeArgv,
                nil,
                NSStringFromClass(AppDelegate.self))
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

class DefaultSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        // No `UIHostingController` in sight. This used to read
        // `UIHostingController(rootView: MainCoordinator().view())` — a UIKit app had to
        // host the coordinator itself, because SwiftUI was the only way in.
        window.rootViewController = MainCoordinator().viewController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
