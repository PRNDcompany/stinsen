import Foundation
import SwiftUI


public struct PushPresentation: PresentationType {

    public init() { }

    public func makePresented<T: NavigationCoordinatable>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented {
        if presentable is AnyView {
            let view = AnyView(StinsenConfigure.shared.navigationCoordinatableView(id: nextId, coordinator: coordinator))

            return Presented(
                view: view,
                type: PushPresentation()
            )
        } else {
            return Presented(
                view: presentable.view(),
                type: PushPresentation()
            )
        }
    }
}
