import SwiftUI
import UIKit

/// A screen, in whichever runtime it was written.
///
/// This is the coordinator's universal currency. It used to be `AnyView`: every screen —
/// a route's output, a root's child, a tab's content — was ultimately a SwiftUI view, so
/// a plain `UIViewController` could not be a screen at all. That is the wrong way round
/// for a library whose transition engine is UIKit.
///
/// ### Resolved late, on purpose
///
/// Both cases are kept as they were authored rather than converted up front, and the
/// conversion happens only at the edge that needs it. That is what keeps each runtime
/// first-class instead of merely supported:
///
/// - A SwiftUI screen rendered by a SwiftUI host stays *real SwiftUI*, so the
///   surrounding `Environment` and `EnvironmentObject`s still reach it.
/// - A UIKit screen presented by UIKit stays *the app's own view controller*, with no
///   hosting controller wrapped around it.
/// - Only crossing over costs an adapter.
///
/// Converting eagerly — making everything a view controller, or making everything a view
/// — would be simpler and would quietly break one side. Wrapping SwiftUI content in a
/// `UIViewControllerRepresentable` in particular severs environment inheritance, because
/// a `UIHostingController` created inside a representable does not inherit the
/// environment around it.
///
/// ### Why an enum and not a protocol
///
/// A protocol would mean conforming `UIViewController` to it, and a library that adds a
/// retroactive conformance to a UIKit type collides with every app and library that does
/// the same. An enum case costs nothing and belongs to us.
@MainActor
public enum Screen {
    case view(AnyView)
    case viewController(UIViewController)
    case coordinator(any Coordinatable)

    /// The screen as UIKit needs it.
    ///
    /// - Parameter presentation: used to build the view controller for SwiftUI content,
    ///   so a custom presentation can supply its own container. A view controller the app
    ///   handed us is returned untouched — it is already the thing to present, and
    ///   rebuilding it would discard the object the app is holding a reference to.
    func makeViewController(using presentation: AnyPresentationType) -> UIViewController {
        switch self {
        case .view(let view):
            return presentation.makeViewController(content: view)
        case .coordinator(let coordinator):
            // A coordinator already answers "what am I, as a view controller", and for the
            // library's own presentations that is the answer to use. Going through
            // `view()` instead threw it away: a `TabCoordinatable` presented modally came
            // back as a hosting controller wrapped around a SwiftUI `TabView` — no
            // `UITabBarItem` to configure, no delegate to hook — in an app that had asked
            // UIKit for everything else. Which is also the stated policy of this type,
            // applied to the case that was skipping it: resolve at the edge that needs it,
            // in the runtime doing the presenting.
            //
            // An app's own presentation keeps building the container itself, because it is
            // typed to whatever its `make` closure returns and cannot be handed something
            // else.
            return presentation.isBuiltIn
                ? coordinator.viewController()
                : presentation.makeViewController(content: coordinator.view())
        case .viewController(let viewController):
            return viewController
        }
    }

    /// The screen as SwiftUI needs it.
    func makeView() -> AnyView {
        switch self {
        case .view(let view):
            return view
        case .coordinator(let coordinator):
            return coordinator.view()
        case .viewController(let viewController):
            // Given the whole space on purpose. A `UIViewControllerRepresentable` has no
            // intrinsic size of its own, so without this it collapses to nothing and the
            // screen is present but invisible — which looks exactly like a screen that
            // failed to appear.
            return AnyView(
                ScreenRepresentable(viewController: viewController)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
    }

    /// The child coordinator this screen shows, if it is one.
    var coordinatorValue: (any Coordinatable)? {
        guard case .coordinator(let coordinator) = self else { return nil }
        return coordinator
    }
}

/// Lets a `Screen` stand where a route's output stands.
///
/// This is what makes `@Root var login = makeLoginViewController` type-check: a route's
/// output has to be `ViewPresentable`, and a bare `UIViewController` is not one — and
/// making it one would mean a retroactive conformance on a UIKit type, which a library
/// has no business adding.
extension Screen: ViewPresentable {
    public func view() -> AnyView { makeView() }

    /// The screen as a view controller, with no presentation to build it.
    ///
    /// Distinct from `makeViewController(using:)`: that one exists for routing, where a
    /// custom presentation may want to supply the container. A root has no presentation
    /// — it is not being put on top of anything.
    public func viewController() -> UIViewController {
        switch self {
        case .view(let view):
            return UIHostingController(rootView: view)
        case .coordinator(let coordinator):
            return coordinator.viewController()
        case .viewController(let viewController):
            return viewController
        }
    }
}

/// Places an existing view controller into a SwiftUI hierarchy.
///
/// Deliberately not a factory: the view controller is the app's, already built, and
/// possibly already on screen. Making a new one per SwiftUI update would hand back a
/// different object than the one the app is driving.
private struct ScreenRepresentable: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController { viewController }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
