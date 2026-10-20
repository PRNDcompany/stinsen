import Foundation
import SwiftUI

@MainActor
public protocol PresentationType {
    func makePresented<T: NavigationCoordinatable>(content: StackItemContent, nextId: Int, coordinator: T) -> ViewControllerPresented?
    func makeViewController<Content: View>(content: Content) -> UIViewController
    func presented(parent: UIViewController, content: UIViewController, onAppeared: @escaping () -> Void, onDismissed: @escaping () -> Void)
    func dismissed(viewController: UIViewController)
}
