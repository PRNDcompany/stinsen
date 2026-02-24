//
//  UIKitPresentationType.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI

#if canImport(UIKit)
public protocol UIKitPresentationType: PresentationType {
    func makeViewController<Content: View>(content: Content) -> UIViewController
    func presented(parent: UIViewController,
                   content: UIViewController,
                   onAppeared: @escaping () -> Void,
                   onDismissed: @escaping () -> Void)
    func dismissed(viewController: UIViewController)
}
#endif
