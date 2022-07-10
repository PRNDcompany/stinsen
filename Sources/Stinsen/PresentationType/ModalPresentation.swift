import Foundation
import SwiftUI


public struct ModalPresentation: PresentationType {
    public init() { }
    
    public func makePresented<T: NavigationCoordinatable>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented {
        if presentable is AnyView {
            let view = AnyView(NavigationCoordinatableView(id: nextId, coordinator: coordinator))
            
#if os(macOS)
            return .view(
                ViewPresented(
                    view: AnyView(
                        NavigationView(
                            content: {
                                view
                            }
                        )
                    ),
                    presentationType: ModalPresentation()
                )
            )
#else
            return .view(
                ViewPresented(
                    view: AnyView(
                        NavigationView(
                            content: {
                                view.navigationBarHidden(true)
                            }
                        )
                        .navigationViewStyle(StackNavigationViewStyle())
                    ),
                    presentationType: ModalPresentation()
                )
            )
#endif
        } else {
            return .view(
                ViewPresented(
                    view: presentable.view(),
                    presentationType: ModalPresentation()
                )
            )
        }
    }
}
