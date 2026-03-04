//
//  AnyPresentationType.swift
//  
//
//  Created by wani on 2022/04/25.
//

import Foundation
import SwiftUI


public struct AnyPresentationType: PresentationType {

    var presentationType: PresentationType

    public init(_ presentationType: PresentationType) {
        self.presentationType = presentationType
    }

    public func makePresented<T>(content: StackItemContent, nextId: Int, coordinator: T) -> ViewControllerPresented? where T : NavigationCoordinatable {
        presentationType.makePresented(content: content, nextId: nextId, coordinator: coordinator)
    }
}

// MARK: - Standard Presentation Types

import UIKit

extension AnyPresentationType {
    /// Push presentation using UINavigationController.
    public static var push: AnyPresentationType {
        AnyPresentationType(UIKitPresentation<UIViewController>(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { parent, viewController in
                parent.navigationController?.pushViewController(viewController, animated: true)
            }
        ))
    }

    /// Modal presentation.
    public static var modal: AnyPresentationType {
        AnyPresentationType(UIKitPresentation<UIViewController>(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { parent, viewController in
                parent.present(viewController, animated: true)
            }
        ))
    }

    /// Full-screen modal presentation.
    public static var fullScreen: AnyPresentationType {
        AnyPresentationType(UIKitPresentation<UIViewController>(
            make: { content, _ in
                let vc = UIHostingController(rootView: content)
                vc.modalPresentationStyle = .fullScreen
                return vc
            },
            present: { parent, viewController in
                viewController.modalPresentationStyle = .fullScreen
                parent.present(viewController, animated: true)
            }
        ))
    }
}

// MARK: - UIKit Method Forwarding

extension AnyPresentationType {
    public func makeViewController<Content: View>(content: Content) -> UIViewController {
        guard let uikit = presentationType as? UIKitPresentationType else {
            assertionFailure("AnyPresentationType: wrapped type does not support makeViewController")
            return UIHostingController(rootView: content)
        }
        return uikit.makeViewController(content: content)
    }

    public func presented(parent: UIViewController,
                          content: UIViewController,
                          onAppeared: @escaping () -> Void,
                          onDismissed: @escaping () -> Void) {
        guard let uikit = presentationType as? UIKitPresentationType else {
            assertionFailure("AnyPresentationType: wrapped type does not support presented")
            return
        }
        uikit.presented(parent: parent, content: content,
                        onAppeared: onAppeared, onDismissed: onDismissed)
    }

    public func dismissed(viewController: UIViewController) {
        guard let uikit = presentationType as? UIKitPresentationType else {
            assertionFailure("AnyPresentationType: wrapped type does not support dismissed")
            return
        }
        uikit.dismissed(viewController: viewController)
    }
}

