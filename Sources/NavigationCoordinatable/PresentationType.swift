import Foundation
import SwiftUI

@MainActor
public protocol PresentationType {
    /// How this presentation puts a screen on screen.
    ///
    /// Lives here rather than on `AnyPresentationType` because it describes the
    /// presentation itself: putting it on the erasing wrapper would mean every consumer
    /// had to downcast to recover it, and a bare `UIKitPresentation` that pushes would
    /// be misreported as `.custom`.
    var kind: PresentationKind { get }

    func makePresented<T: NavigationCoordinatable>(content: StackItemContent, nextId: Int, coordinator: T) -> ViewControllerPresented?
    func makeViewController<Content: View>(content: Content) -> UIViewController
    func presented(parent: UIViewController, content: UIViewController, onAppeared: @escaping () -> Void, onDismissed: @escaping () -> Void)
    func dismissed(viewController: UIViewController)
}

public extension PresentationType {
    /// Anything that does not say otherwise is, by definition, custom — so existing
    /// conformers keep compiling and keep their current behaviour.
    var kind: PresentationKind { .custom }
}
