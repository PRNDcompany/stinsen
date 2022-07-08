//
//  UIKitPresentationType.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI

#if os(iOS)
public protocol UIKitPresentationType: PresentationType {
    func presented<Content: View>(parent: UIViewController, content: Content?, onAppeared: @escaping () -> Void, onDissmissed: @escaping () -> Void)
    func dismissed(viewController: UIViewController)
}
#endif
