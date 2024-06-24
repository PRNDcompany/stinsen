//
//  AnyPresentationType.swift
//  
//
//  Created by wani on 2022/04/25.
//

import Foundation
import SwiftUI


public struct AnyPresentationType: PresentationType {

    var parsentationType: PresentationType

    public init(_ parsentationType: PresentationType) {
        self.parsentationType = parsentationType
    }

    public func makePresented<T>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented where T : NavigationCoordinatable {
        parsentationType.makePresented(presentable: presentable, nextId: nextId, coordinator: coordinator)
    }
}

