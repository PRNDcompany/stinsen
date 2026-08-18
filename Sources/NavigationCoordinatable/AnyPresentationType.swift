import Foundation
import SwiftUI
import UIKit

public struct AnyPresentationType: PresentationType {

    var presentationType: PresentationType

    /// Forwarded from the wrapped presentation, so erasing does not lose it.
    public var kind: PresentationKind { presentationType.kind }

    /// Whether this library built the presentation, rather than the app.
    ///
    /// Not the same question as `kind`, and the difference matters. `kind` is *declared*
    /// by whoever built the presentation — the initialisers take it as a parameter — so an
    /// app's own presentation is free to call itself `.push`, and one that does is not a
    /// push at all. Teardown used to read `kind`: a presentation claiming `.push` was
    /// batch-popped through UIKit, and its `dismiss` closure — the reverse animation, the
    /// app's own cleanup — was skipped entirely.
    ///
    /// Only the three factories below set this, and only the file that defines them can,
    /// so it cannot be claimed from outside. `kind` keeps its declared meaning and is
    /// still what diagnostics read, which is what it is good for: "this was *meant* to be
    /// a push" is worth saying even when it is wrong.
    private(set) var isBuiltIn = false

    public init(_ presentationType: PresentationType) {
        // Erasing something already erased returns it unchanged rather than nesting.
        //
        // The imperative `route(_:to:)` overloads take an `AnyPresentationType` and pass it
        // on as a `PresentationType`, so every one of them arrived here to be wrapped a
        // second time. `kind` survived that because it is computed and forwards; anything
        // *stored* did not — a second wrapper is a fresh value with default state, and it
        // buried `isBuiltIn` under itself. So `.modal` reached the host as "not ours", and
        // the one thing the flag exists to decide was decided the wrong way.
        if let alreadyErased = presentationType as? AnyPresentationType {
            self = alreadyErased
            return
        }
        self.presentationType = presentationType
    }

    public func makePresented<T>(content: StackItemContent, nextId: Int, coordinator: T) -> ViewControllerPresented? where T: NavigationCoordinatable {
        presentationType.makePresented(content: content, nextId: nextId, coordinator: coordinator)
    }

    public func makeViewController<Content: View>(content: Content) -> UIViewController {
        presentationType.makeViewController(content: content)
    }

    public func presented(parent: UIViewController,
                          content: UIViewController,
                          onAppeared: @escaping () -> Void,
                          onDismissed: @escaping () -> Void) {
        presentationType.presented(parent: parent, content: content,
                                   onAppeared: onAppeared, onDismissed: onDismissed)
    }

    public func dismissed(viewController: UIViewController) {
        presentationType.dismissed(viewController: viewController)
    }
}

// MARK: - Convenience Initializers

extension AnyPresentationType {
    /// Create an AnyPresentationType directly with closures.
    public init<VC: UIViewController>(
        make: @escaping (AnyView, @escaping () -> Void) -> VC,
        present: @escaping (UIViewController, VC) -> Void,
        dismiss: @escaping (UIViewController) -> Void,
        kind: PresentationKind = .custom
    ) {
        self.init(UIKitPresentation(make: make, present: present, dismiss: dismiss, kind: kind))
    }

    /// Create an AnyPresentationType with closures (default dismiss behavior).
    public init<VC: UIViewController>(
        make: @escaping (AnyView, @escaping () -> Void) -> VC,
        present: @escaping (UIViewController, VC) -> Void,
        kind: PresentationKind = .custom
    ) {
        self.init(UIKitPresentation(make: make, present: present, kind: kind))
    }
}

// MARK: - Standard Presentation Types

// The built-in presentations are typed to `UIViewController`, not to the
// `UIHostingController` their `make` closure happens to return.
//
// `UIKitPresentation` casts the content down to its `ViewController` parameter before
// handing it to `present`, so a presentation typed to `UIHostingController<AnyView>` can
// only ever present SwiftUI content the library built itself — a view controller the app
// supplied fails the cast and hits an assertion. Widening the parameter is what lets
// `route(.push, to: MyViewController())` work at all, and it costs nothing: `make` may
// still return whatever subclass it likes.
extension AnyPresentationType {

    /// The same closures as the public initialiser, plus the one thing an app cannot
    /// claim for itself: that this presentation is the library's own, and so its teardown
    /// is ours to collapse.
    private static func builtIn(
        make: @escaping (AnyView, @escaping () -> Void) -> UIViewController,
        present: @escaping (UIViewController, UIViewController) -> Void,
        kind: PresentationKind
    ) -> AnyPresentationType {
        var presentation = AnyPresentationType(make: make, present: present, kind: kind)
        presentation.isBuiltIn = true
        return presentation
    }

    /// Push presentation using UINavigationController.
    public static var push: AnyPresentationType {
        builtIn(
            make: { content, _ -> UIViewController in UIHostingController(rootView: content) },
            present: { parent, viewController in
                parent.navigationController?.pushViewController(viewController, animated: true)
            },
            kind: .push
        )
    }

    /// Modal presentation.
    public static var modal: AnyPresentationType {
        builtIn(
            make: { content, _ -> UIViewController in UIHostingController(rootView: content) },
            present: { parent, viewController in
                parent.present(viewController, animated: true)
            },
            kind: .modal
        )
    }

    /// Full-screen modal presentation.
    public static var fullScreen: AnyPresentationType {
        builtIn(
            make: { content, _ -> UIViewController in
                let vc = UIHostingController(rootView: content)
                vc.modalPresentationStyle = .fullScreen
                return vc
            },
            present: { parent, viewController in
                viewController.modalPresentationStyle = .fullScreen
                parent.present(viewController, animated: true)
            },
            kind: .fullScreen
        )
    }
}
