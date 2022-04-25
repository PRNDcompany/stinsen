import SwiftUI

public struct Presented {
    public var view: AnyView
    public var type: PresentationType

    public init(view: AnyView, type: PresentationType) {
        self.view = view
        self.type = type
    }
}
