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

    public func makePresented<T>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> ViewControllerPresented? where T : NavigationCoordinatable {
        presentationType.makePresented(presentable: presentable, nextId: nextId, coordinator: coordinator)
    }
}

