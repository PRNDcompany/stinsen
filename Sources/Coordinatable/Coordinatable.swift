import Foundation
import SwiftUI
import UIKit

/// A Coordinatable usually represents some kind of flow in the app. You do not need to implement this directly if you're not toying with other types of navigation e.g. a hamburger menu, but rather you would implement TabCoordinatable, NavigationCoordinatable or ViewCoordinatable.
public protocol Coordinatable: ObservableObject, Identifiable, ViewPresentable, ChildDismissable {
    var parent: ChildDismissable? { get set }

    /// Configures the view controller the library just built to stand for this coordinator.
    ///
    /// The UIKit counterpart to `customize(_:)`, and the same idea from the other side. A
    /// coordinator hosted by UIKit *is* a `UIViewController`, and a view controller is
    /// configured through its own properties — `title`, `tabBarItem`, `navigationItem`,
    /// `modalPresentationStyle`, `isModalInPresentation`, `overrideUserInterfaceStyle` —
    /// none of which any SwiftUI modifier reaches.
    ///
    /// Declared here rather than on `NavigationCoordinatable` and `TabCoordinatable`
    /// separately for three reasons: one declaration cannot be ambiguous for a type that
    /// conforms to both, a wrapper can forward it to the coordinator it decorates without
    /// knowing which kind that is, and `AnyCoordinator` can carry it through erasure.
    ///
    /// ### When it runs
    ///
    /// Once per view controller the library builds for this coordinator, immediately after
    /// building it and before anything presents it. `viewController()` is a factory, so
    /// asking twice gives two controllers and two calls to this — put per-instance setup
    /// here, and expect it to run per instance.
    ///
    /// It is **not** called on the SwiftUI path (`view()`) — `customize(_:)` is the hook
    /// there — and not when a screen's container is built by an app's own presentation,
    /// which is typed to its own container and renders the coordinator as SwiftUI.
    ///
    /// - Note: a route declaration outranks this. `.fullScreen` re-asserts
    ///   `modalPresentationStyle` when it presents, and a tab declared with `tabBarItem:`
    ///   overwrites one set here — the parent decides *how* a child is shown, while this
    ///   decides what the child *is*. `.modal` does not touch presentation style, so
    ///   choosing `.formSheet` here works.
    /// - Note: if you implement `viewController()` yourself, your implementation wins over
    ///   the library's and nothing calls this for you. Call it yourself.
    @MainActor func configure(_ viewController: UIViewController)
}

public extension Coordinatable {
    nonisolated var id: String {
        return ObjectIdentifier(self).debugDescription
    }

    @MainActor func configure(_ viewController: UIViewController) {}
}

@MainActor
internal extension Coordinatable {

    /// This coordinator's SwiftUI view, hosted, and then handed to `configure(_:)`.
    ///
    /// The one place the hosting default is spelled out for a *coordinator*, so that no
    /// `viewController()` implementation — now or later — can host a view and forget the
    /// hook. `ViewPresentable` keeps its own copy of the same two lines because it also
    /// serves `AnyView` and `Screen`, which have no `configure(_:)` to call; that
    /// duplication is the price of not putting a coordinator's hook on the protocol
    /// `AnyView` conforms to.
    func hostedViewController() -> UIViewController {
        let viewController = UIHostingController(rootView: view())
        configure(viewController)
        return viewController
    }
}
