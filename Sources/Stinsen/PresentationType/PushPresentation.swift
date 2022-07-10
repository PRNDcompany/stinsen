import Foundation
import SwiftUI


public struct PushPresentation: PresentationType {
    
    public init() { }
    
    public func makePresented<T: NavigationCoordinatable>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented {
        if presentable is AnyView {
            let view = AnyView(NavigationCoordinatableView(id: nextId, coordinator: coordinator))
            
            return .view(
                ViewPresented(
                    view: view,
                    presentationType: PushPresentation()
                )
            )
        } else {
            return .view(
                ViewPresented(
                    view: presentable.view(),
                    presentationType: PushPresentation()
                )
            )
        }
    }
}
