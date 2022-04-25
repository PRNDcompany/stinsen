//
//  StinsenConfigure.swift
//
//
//  Created by wani on 2022/04/22.
//

import Foundation
import SwiftUI




extension AnyPresentationType {
    public static var push = AnyPresentationType(PushPresentation())
    public static var modal = AnyPresentationType(ModalPresentation())
}


open class StinsenConfigure {
    public static var shared: StinsenConfigure = StinsenConfigure()

    public init() {

    }

    open func navigationModifier<Root: View>(rootView: Root, presented: Presented?, id: Int, appear: @escaping (Int) -> Void, dismissalAction: (() -> Void)? ) -> AnyView {
        AnyView(rootView)
    }

    public func navigationCoordinatableView<T: NavigationCoordinatable>(id: Int, coordinator: T) -> some View {
        NavigationCoordinatableView(id: id, coordinator: coordinator)
    }
}
