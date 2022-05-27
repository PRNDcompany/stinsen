//
//  UIKitPresentation.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI

#if os(iOS)
public struct UIKitPresentation: UIKitPresentationType {

    var presentHandler: ((_ parent: UIViewController, _ content: AnyView, _ dissmiss: @escaping () -> Void) -> Void)
    var dismissHandler: ((UIViewController) -> Void)

    public init(present presentHandler: @escaping ((UIViewController, AnyView, @escaping () -> Void) -> Void), dismiss dismissHandler: @escaping ((UIViewController) -> Void)) {
        self.presentHandler = presentHandler
        self.dismissHandler = dismissHandler
    }

    public init(present presentHandler: @escaping ((UIViewController, AnyView, @escaping () -> Void) -> Void)) {
        self.presentHandler = presentHandler
        self.dismissHandler = { parent in
            guard let presentedViewController = parent.presentedViewController else {
                return
            }
            if presentedViewController.presentedViewController == nil {
                presentedViewController.dismiss(animated: true)
            } else {
                parent.dismiss(animated: true)
            }
        }
    }


    public func makePresented<T: NavigationCoordinatable>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented {
        if presentable is AnyView {
            let view = AnyView(NavigationCoordinatableView(id: nextId, coordinator: coordinator))
            
            return Presented(
                view: view,
                type: self
            )
        } else {
            return Presented(
                view: presentable.view(),
                type: self
            )
        }
    }

    public func presented<Content: View>(parent: UIViewController, content: Content?) {
        guard let content = content else {
            return
        }
        presentHandler(
            parent,
            AnyView(content),
            { [weak parent] in
                guard let parent = parent else { return }
                dismissHandler(parent)
            }
        )
    }

    public func dismissed(parent: UIViewController) {
        dismissHandler(parent)
    }

}
#endif
