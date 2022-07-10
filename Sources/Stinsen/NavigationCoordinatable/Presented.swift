import SwiftUI



public enum Presented {

    case view(ViewPresented)
    case viewController(ViewControllerPresented)

    public var view: AnyView {
        switch self {
        case let .view(presented):
            return presented.view
        case .viewController:
            return AnyView(EmptyView())
        }
    }

    public var type: PresentationType {
        switch self {
        case let .view(presented):
            return presented.presentationType
        case let .viewController(presented):
            return presented.presentationType
        }
    }
}
