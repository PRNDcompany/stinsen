import Foundation
import SwiftUI


public struct ModalPresentation: PresentationType {
    public init() { }

    public func makePresented<T: NavigationCoordinatable>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented {
        if presentable is AnyView {
            let view = AnyView(NavigationCoordinatableView(id: nextId, coordinator: coordinator))

            #if os(macOS)
            return Presented(
                view: AnyView(
                    NavigationView(
                        content: {
                            view
                        }
                    )
                ),
                type: ModalPresentation()
            )
            #else
            return Presented(
                view: AnyView(
                    NavigationView(
                        content: {
                            view.navigationBarHidden(true)
                        }
                    )
                    .navigationViewStyle(StackNavigationViewStyle())
                ),
                type: ModalPresentation()
            )
            #endif
        } else {
            return Presented(
                view: presentable.view(),
                type: ModalPresentation()
            )
        }
    }
}
