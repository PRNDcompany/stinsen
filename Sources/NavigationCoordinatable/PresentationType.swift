import Foundation
import SwiftUI



public protocol PresentationType {
    func makePresented<T: NavigationCoordinatable>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented
}
