//
//  UIKitPresentation.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI

#if os(iOS)
public struct UIKitPresentation: UIKitPresentationType {

    var presentHandler: ((_ parent: UIViewController, _ content: AnyView) -> Void)?

    public init(presentHandler: ((UIViewController, AnyView) -> Void)? = nil) {
        self.presentHandler = presentHandler
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
        presentHandler?(parent, AnyView(content))
    }
}
#endif
