//
//  UIKitPresentationType.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI

#if os(iOS)
public protocol UIKitPresentationType: PresentationType {
    func presented<Content: View>(parent: UIViewController, content: Content?)
    func dismissed(parent: UIViewController)
}
#endif
