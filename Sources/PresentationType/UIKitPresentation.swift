//
//  UIKitPresentation.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI



public struct UIKitPresentation<ViewController: UIViewController>: PresentationType {


    public typealias MakeUIViewControllerHandler = (_ content: AnyView, _ dismissHandler: @escaping () -> Void) -> ViewController
    public typealias DismissHandler = (_ viewController: UIViewController) -> Void
    public typealias PresentHandler = (_ parent: UIViewController, _ viewController: ViewController) -> Void


    var makeUIViewController: MakeUIViewControllerHandler
    var presentHandler: PresentHandler
    var dismissHandler: DismissHandler

    public let kind: PresentationKind

    public init(make makeUIViewController: @escaping MakeUIViewControllerHandler,
                present presentHandler: @escaping PresentHandler,
                dismiss dismissHandler: @escaping DismissHandler,
                kind: PresentationKind = .custom) {
        self.makeUIViewController = makeUIViewController
        self.presentHandler = presentHandler
        self.dismissHandler = dismissHandler
        self.kind = kind
    }

    public init(make makeUIViewController: @escaping MakeUIViewControllerHandler,
                present presentHandler: @escaping PresentHandler,
                kind: PresentationKind = .custom) {
        self.makeUIViewController = makeUIViewController
        self.presentHandler = presentHandler
        self.kind = kind
        self.dismissHandler = { viewController in
            // `> 1`, not `> 2`: a root plus this one screen already means there is
            // something to go back to. With the old threshold the first pushed screen
            // fell through to `dismiss(animated:)`, which does nothing at all to a
            // *pushed* view controller — so "go back" silently did nothing at depth one.
            if let navigationController = viewController.navigationController,
               navigationController.viewControllers.count > 1 {
                viewController.navigationController?.popViewController(animated: true)
            } else {
                // NOTE: Dismiss from presenting VC to close any presented VCs at once
                if viewController.presentedViewController != nil {
                    viewController.presentingViewController?.dismiss(animated: true)
                } else {
                    viewController.dismiss(animated: true)
                }
            }
        }
    }

    public func makePresented<T: NavigationCoordinatable>(content: StackItemContent, nextId: Int, coordinator: T) -> ViewControllerPresented? {
        // The content is turned into a view controller as it is. It used to be wrapped in
        // another `NavigationCoordinatableView` carrying `nextId`, whose only job was to
        // introspect its way to a view controller so *the next* level could be presented
        // from it. `NavigationHost` owns every level now, so there is nothing left for
        // the wrapper to do — and `nextId` names a position that no longer exists.
        ViewControllerPresented(
            viewController: content.makeViewController(using: AnyPresentationType(self)),
            presentationType: self
        )
    }

    public func makeViewController<Content>(content: Content) -> UIViewController where Content : View {
        weak var dismissViewController: UIViewController?
        let viewController = makeUIViewController(AnyView(content), {
            guard let targetViewController = dismissViewController else { return }
            dismissed(viewController: targetViewController)
        })
        dismissViewController = viewController
        return viewController
    }

    /// - Parameter onDismissed: no longer called. Disappearance is observed rather than
    ///   inferred — see the note below. Kept in the signature because it is a public
    ///   protocol requirement and removing it would break every conformer.
    public func presented(parent: UIViewController, content: UIViewController, onAppeared: @escaping () -> Void, onDismissed: @escaping () -> Void) {
        // `onDismissed` used to be driven by an associated object whose `deinit` fired
        // it. That was the only way to notice a screen going away before the coordinator
        // could ask UIKit — but it depended on ARC: it arrived whenever the view
        // controller was finally released, in no particular order, and never at all if
        // anything still retained it. `ScreenProbe` reports the disappearance with a
        // reason, and `reconcile()` re-derives from UIKit on every operation, so nothing
        // is left for it to do.
        //
        // It also planted a hidden object on a view controller the app may own, which
        // stops being defensible the moment app-supplied view controllers can be screens.
        guard let typedContent = content as? ViewController else {
            assertionFailure("""
                Stinsen: this presentation can only present \(ViewController.self), but \
                it was given \(type(of: content)). A presentation built with \
                `AnyPresentationType(make:present:)` is typed to whatever `make` returns, \
                so it cannot be used to present a view controller of another type.
                """)
            return
        }
        presentHandler(
            parent,
            typedContent
        )

        // A run loop hop, not a transition completion — the accurate signal is the
        // screen's own `viewDidAppear`, which `NavigationHost` observes through its probe.
        DispatchQueue.main.async {
            onAppeared()
        }
    }

    public func dismissed(viewController: UIViewController) {
        dismissHandler(viewController)
    }

}
