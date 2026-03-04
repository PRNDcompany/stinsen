import Foundation
import SwiftUI



public protocol PresentationType {
    func makePresented<T: NavigationCoordinatable>(content: StackItemContent, nextId: Int, coordinator: T) -> ViewControllerPresented?
}
