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

