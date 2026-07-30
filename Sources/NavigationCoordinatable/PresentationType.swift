import Foundation
import SwiftUI

@MainActor
public protocol PresentationType {
    /// - Parameter itemUid: Identity of the stack item being presented.
    /// - Parameter onRemoved: Removal notification, born in PresentationController.
    ///   Injected at creation time so detection can be wired where the view controller is made.
    func makePresented<T: NavigationCoordinatable>(content: StackItemContent, nextId: Int, coordinator: T, itemUid: UUID, onRemoved: @escaping () -> Void) -> ViewControllerPresented?
    func makeViewController<Content: View>(content: Content) -> UIViewController
    func presented(parent: UIViewController, content: UIViewController)
    func dismissed(viewController: UIViewController)
}
