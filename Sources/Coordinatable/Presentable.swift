import Foundation
import SwiftUI
import UIKit

/// A `ViewPresentable` is something that can presented as a view. It can either be a view (AnyView) or a coordinator (Coordinatable)
@MainActor
public protocol ViewPresentable {
    /// This function is used internally for Stinsen. Do not implement this directly in a coordinator, it will use the a standard implementation derived from the coordinatable you're implementing. Returns a view for the presentable.
    func view() -> AnyView

    /// The same thing, as UIKit sees it.
    ///
    /// This is what a UIKit app starts from:
    ///
    /// ```swift
    /// window.rootViewController = MainCoordinator().viewController()
    /// ```
    ///
    /// Until now the only way in was `view()`, so a UIKit app had to wrap it in a
    /// `UIHostingController` itself — the example app's `SceneDelegate` did exactly that,
    /// which is the cost showing up in the one place that was meant to demonstrate the
    /// library.
    ///
    /// Do not implement this directly in a coordinator; each coordinator type supplies
    /// its own.
    func viewController() -> UIViewController
}

public extension ViewPresentable {
    /// Anything that can only describe itself as SwiftUI is hosted.
    ///
    /// Coordinators override this with something that hosts their screens natively, so
    /// the wrapper only appears where SwiftUI content genuinely has to become a view
    /// controller.
    func viewController() -> UIViewController {
        UIHostingController(rootView: view())
    }
}

extension AnyView: ViewPresentable {
    nonisolated public func view() -> AnyView {
        return self
    }
}
