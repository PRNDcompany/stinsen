import Foundation
import SwiftUI
import UIKit

public struct AnyPresentationType: PresentationType {

    var presentationType: PresentationType

    /// Forwarded from the wrapped presentation, so erasing does not lose it.
    public var kind: PresentationKind { presentationType.kind }

    public init(_ presentationType: PresentationType) {
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

extension AnyPresentationType {
    /// Push presentation using UINavigationController.
    public static var push: AnyPresentationType {
        AnyPresentationType(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { parent, viewController in
                parent.navigationController?.pushViewController(viewController, animated: true)
            },
            kind: .push
        )
    }

    /// Modal presentation.
    public static var modal: AnyPresentationType {
        AnyPresentationType(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { parent, viewController in
                parent.present(viewController, animated: true)
            },
            kind: .modal
        )
    }

    /// Full-screen modal presentation.
    public static var fullScreen: AnyPresentationType {
        AnyPresentationType(
            make: { content, _ in
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
