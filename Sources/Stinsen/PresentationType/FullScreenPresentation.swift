import Foundation
import SwiftUI


public struct FullScreenPresentation: PresentationType {

    public init() { }

    public func makePresented<T: NavigationCoordinatable>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented {
        if #available(iOS 14, tvOS 14, watchOS 7, *) {
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
                    type: FullScreenPresentation()
                )
#else
                return Presented(
                    view: AnyView(
                        NavigationView(
                            content: {
#if os(macOS)
                                view
#else
                                view.navigationBarHidden(true)
#endif
                            }
                        )
                        .navigationViewStyle(StackNavigationViewStyle())
                    ),
                    type: FullScreenPresentation()
                )
#endif
            } else {
                return Presented(
                    view: AnyView(
                        presentable.view()
                    ),
                    type: FullScreenPresentation()
                )
            }
        } else {
            fatalError()
        }
    }
}
