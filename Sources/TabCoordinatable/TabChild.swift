import Foundation
import SwiftUI
import UIKit
import Combine

struct TabChildItem {
    let presentable: ViewPresentable
    let keyPathIsEqual: (Any) -> Bool
    let tabItem: (Bool) -> AnyView

    /// How this tab looks to a `UITabBarController`.
    ///
    /// Returns `nil` when the route only declared a SwiftUI tab item. A SwiftUI view
    /// cannot become a `UITabBarItem` — the two describe a tab in different terms, and
    /// rendering one into an image to fake the other would be worse than saying so.
    let tabBarItem: () -> UITabBarItem?

    let onTapped: (Bool) -> Void
}

/// Wrapper around childCoordinators
/// Used so that you don't need to write @Published
@MainActor
public class TabChild: ObservableObject {
    weak var parent: ChildDismissable?
    public let startingItems: [AnyKeyPath]
    
    @Published var activeItem: TabChildItem!
    
    var allItems: [TabChildItem]!
    
    public var activeTab: Int {
        didSet {
            allItems[activeTab].onTapped(oldValue == activeTab)
            // Announced even when the value did not change, so a re-tap is observable.
            activeTabDidChange.send(activeTab)
            guard oldValue != activeTab else { return }
            let newItem = allItems[activeTab]
            self.activeItem = newItem
        }
    }

    /// Fires whenever `activeTab` is assigned.
    ///
    /// `activeItem` is `@Published` but only changes when the tab actually changes, and
    /// it carries the item rather than the index — neither of which is what a
    /// `UITabBarController` needs to keep its selection in step.
    let activeTabDidChange = PassthroughSubject<Int, Never>()
    
    public init(startingItems: [AnyKeyPath], activeTab: Int = 0) {
        self.startingItems = startingItems
        self.activeTab = activeTab
    }

    /// Imperative initializer - use with `addTab` methods on TabCoordinatable
    public convenience init(activeTab: Int = 0) {
        self.init(startingItems: [], activeTab: activeTab)
        self.allItems = []
    }
}

extension TabChild {
    public var allItemViews: [AnyView]? {
        guard allItems != nil else { return nil }
        guard !allItems.isEmpty else { return nil }
        return allItems.map { $0.presentable.view() }
    }
}
