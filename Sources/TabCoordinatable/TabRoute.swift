import Foundation
import SwiftUI
import UIKit

protocol Outputable {
    func using(coordinator: Any) -> ViewPresentable
    func tabItem(active: Bool, coordinator: Any) -> AnyView
    /// `nil` when the route declared only a SwiftUI tab item.
    func tabBarItem(coordinator: Any) -> UITabBarItem?
    func onTapped(_ isRepeat: Bool, coordinator: Any)
}

public class Content<T: TabCoordinatable, Output: ViewPresentable>: Outputable {
    
    func tabItem(active: Bool, coordinator: Any) -> AnyView {
        return self.tabItem(coordinator as! T)(active)
    }

    func tabBarItem(coordinator: Any) -> UITabBarItem? {
        guard let make = self.makeTabBarItem else { return nil }
        return make(coordinator as! T)()
    }
    
    func using(coordinator: Any) -> ViewPresentable {
        let closureOutput = self.closure(coordinator as! T)()
        self.output = closureOutput
        return closureOutput
    }
    
    func onTapped(_ isRepeat: Bool, coordinator: Any) {
        self.onTapped(coordinator as! T)(isRepeat, output!)
    }
    
    let closure: ((T) -> (() -> Output))
    let tabItem: ((T) -> ((Bool) -> AnyView))
    let makeTabBarItem: ((T) -> (() -> UITabBarItem))?
    let onTapped: ((T) -> ((Bool, Output) -> Void))
    
    private var output: Output?
    
    init<TabItem: View>(
        closure: @escaping ((T) -> (() -> Output)),
        tabItem: @escaping ((T) -> ((Bool) -> TabItem)),
        tabBarItem: ((T) -> (() -> UITabBarItem))? = nil,
        onTapped: @escaping ((T) -> ((Bool, Output) -> Void))
    ) {
        self.makeTabBarItem = tabBarItem
        self.closure = closure
        self.tabItem = { coordinator in
            return {
                AnyView(tabItem(coordinator)($0))
            }
        }
        self.onTapped = { coordinator in
            onTapped(coordinator)
        }
    }
}

@propertyWrapper public class TabRoute<T: TabCoordinatable, Output: ViewPresentable> {
    public var wrappedValue: Content<T, Output>
    
    fileprivate init(standard: Content<T, Output>) {
        self.wrappedValue = standard
    }
}

extension TabRoute where T: TabCoordinatable, Output == AnyView {
    public convenience init<ViewOutput: View, TabItem: View>(
        wrappedValue: @escaping ((T) -> (() -> ViewOutput)),
        tabItem: @escaping ((T) -> ((Bool) -> TabItem))
    ) {
        self.init(
            standard: Content(
                closure: { coordinator in { AnyView(wrappedValue(coordinator)()) }},
                tabItem: tabItem,
                onTapped: { _ in { _, _ in }}
            )
        )
    }
    
    public convenience init<ViewOutput: View, TabItem: View>(
        wrappedValue: @escaping ((T) -> (() -> ViewOutput)),
        tabItem: @escaping ((T) -> ((Bool) -> TabItem)),
        onTapped: @escaping ((T) -> ((Bool, Output) -> Void))
    ) {
        self.init(standard: Content(
            closure: { coordinator in { AnyView(wrappedValue(coordinator)()) }},
            tabItem: tabItem,
            onTapped: onTapped))
    }
}

extension TabRoute where T: TabCoordinatable, Output: Coordinatable {
    public convenience init<TabItem: View>(
        wrappedValue: @escaping ((T) -> (() -> Output)),
        tabItem: @escaping ((T) -> ((Bool) -> TabItem))
    ) {
        self.init(
            standard: Content(
                closure: { coordinator in { wrappedValue(coordinator)() }},
                tabItem: tabItem,
                onTapped: { _ in { _, _ in }}
            )
        )
    }
    
    public convenience init<TabItem: View>(
        wrappedValue: @escaping ((T) -> (() -> Output)),
        tabItem: @escaping ((T) -> ((Bool) -> TabItem)),
        onTapped: @escaping ((T) -> ((Bool, Output) -> Void))
    ) {
        self.init(standard: Content(
            closure: { coordinator in { wrappedValue(coordinator)() }},
            tabItem: tabItem,
            onTapped: onTapped))
    }
}

// MARK: - UITabBarItem overloads
//
// A tab declared for a `UITabBarController`. Separate from the SwiftUI `tabItem:`
// initialisers rather than replacing them: a coordinator can declare both and be hosted
// either way, and a SwiftUI view genuinely cannot be turned into a `UITabBarItem`.

extension TabRoute where T: TabCoordinatable, Output == AnyView {
    public convenience init<ViewOutput: View, TabItem: View>(
        wrappedValue: @escaping ((T) -> (() -> ViewOutput)),
        tabItem: @escaping ((T) -> ((Bool) -> TabItem)),
        tabBarItem: @escaping ((T) -> (() -> UITabBarItem)),
        onTapped: ((T) -> ((Bool, Output) -> Void))? = nil
    ) {
        self.init(standard: Content(
            closure: { coordinator in { AnyView(wrappedValue(coordinator)()) }},
            tabItem: tabItem,
            tabBarItem: tabBarItem,
            onTapped: onTapped ?? { _ in { _, _ in }}))
    }
}

extension TabRoute where T: TabCoordinatable, Output: Coordinatable {
    public convenience init<TabItem: View>(
        wrappedValue: @escaping ((T) -> (() -> Output)),
        tabItem: @escaping ((T) -> ((Bool) -> TabItem)),
        tabBarItem: @escaping ((T) -> (() -> UITabBarItem)),
        onTapped: ((T) -> ((Bool, Output) -> Void))? = nil
    ) {
        self.init(standard: Content(
            closure: { coordinator in { wrappedValue(coordinator)() }},
            tabItem: tabItem,
            tabBarItem: tabBarItem,
            onTapped: onTapped ?? { _ in { _, _ in }}))
    }
}
