import Foundation
import SwiftUI

/// The TabCoordinatable is used to represent a coordinator with a TabView
@MainActor
public protocol TabCoordinatable: Coordinatable {
    typealias Route = TabRoute
    typealias Router = TabRouter<Self>
    var child: TabChild { get }

    associatedtype CustomizeViewType: View

    /**
     Implement this function if you wish to customize the view on all views and child coordinators, for instance, if you wish to change the `tintColor` or inject an `EnvironmentObject`.

     - Parameter view: The input view.

     - Returns: The modified view.
     */
    func customize(_ view: AnyView) -> CustomizeViewType

    /**
     Searches the tabbar for the first route that matches the route and makes it the active tab.

     - Parameter route: The route that will be focused.
     */
    @discardableResult func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Output

    /**
     Searches the tabbar for the first route that matches the route and makes it the active tab.

     - Parameter route: The route that will be focused.
     */
    @discardableResult func focusFirst<Output: View>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Self
}

@MainActor
extension TabCoordinatable {

    /// The tabs that are themselves coordinators, unwrapped from any erasure box.
    ///
    /// A teardown cascade needs these: closing the screen that holds a tab coordinator
    /// removes its tabs' screens too, and each tab that is a coordinator keeps its own
    /// records and its own `onDismiss` closures.
    ///
    /// Read from `allItems` rather than from `startingItems`, so a coordinator built with
    /// the imperative `addTab` is included — those have no key paths at all.
    var tabbedCoordinators: [any Coordinatable] {
        (child.allItems ?? []).compactMap { $0.presentable as? any Coordinatable }
    }
}

@MainActor
public extension TabCoordinatable {
    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        fatalError("Not implemented")
    }

    var parent: ChildDismissable? {
        get {
            return child.parent
        } set {
            child.parent = newValue
        }
    }

    func setupAllTabs() {
        var all: [TabChildItem] = []

        for abs in self.child.startingItems {
            let ina = self[keyPath: abs]

            if let val = ina as? Outputable {
                all.append(
                    TabChildItem(
                        presentable: val.using(coordinator: self),
                        keyPathIsEqual: {
                            let lhs = abs as! PartialKeyPath<Self>
                            let rhs = $0 as! PartialKeyPath<Self>
                            return (lhs == rhs)
                        },
                        tabItem: { [unowned self] in
                            val.tabItem(active: $0, coordinator: self)
                        },
                        tabBarItem: { [unowned self] in
                            val.tabBarItem(coordinator: self)
                        },
                        onTapped: { isRepeat in
                            val.onTapped(isRepeat, coordinator: self)
                        }
                    )
                )
            }
        }

        self.child.allItems = all
    }

    func customize(_ view: AnyView) -> some View {
        return view
    }

    func view() -> AnyView {
        AnyView(
            TabCoordinatableView(
                paths: self.child.startingItems,
                coordinator: self,
                customize: customize
            )
        )
    }

    /// The tabs as a real `UITabBarController`.
    ///
    /// The same `TabChild` drives both this and the SwiftUI `TabView` from `view()`, so
    /// `focusFirst`, `selectTab` and the re-tap callback behave identically either way.
    ///
    /// - Note: `customize(_:)` does not apply here — it is a SwiftUI view modifier and there
    ///   is no SwiftUI view to modify. `configure(_:)` is the hook for this path, and it
    ///   receives the `UITabBarController` itself.
    ///
    ///   The two are counterparts, not equivalents. Anything `customize` does to the SwiftUI
    ///   *environment* has no expression here, because each tab is hosted individually — an
    ///   `.environmentObject` injected around a `TabView` reaches its tabs, while one
    ///   injected around a `UITabBarController` would reach nothing. Inject those in the tabs
    ///   themselves.
    func viewController() -> UIViewController {
        if child.allItems == nil {
            setupAllTabs()
        }
        let tabBarController = CoordinatorTabBarController(coordinator: self, child: child)
        configure(tabBarController)
        #if DEBUG
        if tabBarController.delegate !== tabBarController {
            print("""
                Stinsen: \(type(of: self)) replaced its UITabBarController's delegate in \
                configure(_:). Selection is kept in step through that delegate, so tapping \
                the tab you are already on is no longer observable and selectTab/focusFirst \
                no longer follow the user's taps. Forward to the previous delegate instead \
                of replacing it.
                """)
        }
        #endif
        return tabBarController
    }

    @discardableResult func focusFirst<Output: Coordinatable>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Output {
        if child.allItems == nil {
            setupAllTabs()
        }

        guard let value = child.allItems.enumerated().first(where: { item in
            guard item.element.keyPathIsEqual(route) else {
                return false
            }

            return true
        }) else {
            fatalError()
        }

        self.child.activeTab = value.offset

        return value.element.presentable as! Output
    }

    @discardableResult func focusFirst<Output: View>(
        _ route: KeyPath<Self, Content<Self, Output>>
    ) -> Self {
        if child.allItems == nil {
            setupAllTabs()
        }

        guard let value = child.allItems.enumerated().first(where: { item in
            guard item.element.keyPathIsEqual(route) else {
                return false
            }

            return true
        }) else {
            fatalError()
        }

        self.child.activeTab = value.offset

        return self
    }

    // MARK: - Imperative Tab API

    /// Adds a view as a tab.
    @discardableResult
    func addTab<Content: View, TabItem: View>(
        _ view: Content,
        tabItem: @escaping (Bool) -> TabItem,
        onTapped: ((Bool) -> Void)? = nil
    ) -> Self {
        if child.allItems == nil { child.allItems = [] }

        child.allItems.append(
            TabChildItem(
                presentable: AnyView(view),
                keyPathIsEqual: { _ in false },
                tabItem: { AnyView(tabItem($0)) },
                tabBarItem: { nil },
                onTapped: { isRepeat in onTapped?(isRepeat) }
            )
        )

        if child.allItems.count == 1 {
            child.activeItem = child.allItems[0]
        }

        return self
    }

    /// Adds a coordinator as a tab.
    @discardableResult
    func addTab<Output: Coordinatable, TabItem: View>(
        _ coordinator: Output,
        tabItem: @escaping (Bool) -> TabItem,
        onTapped: ((Bool, Output) -> Void)? = nil
    ) -> Output {
        if child.allItems == nil { child.allItems = [] }

        child.allItems.append(
            TabChildItem(
                presentable: coordinator,
                keyPathIsEqual: { _ in false },
                tabItem: { AnyView(tabItem($0)) },
                tabBarItem: { nil },
                onTapped: { isRepeat in onTapped?(isRepeat, coordinator) }
            )
        )

        if child.allItems.count == 1 {
            child.activeItem = child.allItems[0]
        }

        return coordinator
    }

    /// Adds a view as a tab, described for both hosts.
    @discardableResult
    func addTab<Content: View, TabItem: View>(
        _ view: Content,
        tabItem: @escaping (Bool) -> TabItem,
        tabBarItem: @escaping () -> UITabBarItem,
        onTapped: ((Bool) -> Void)? = nil
    ) -> Self {
        if child.allItems == nil { child.allItems = [] }

        child.allItems.append(
            TabChildItem(
                presentable: AnyView(view),
                keyPathIsEqual: { _ in false },
                tabItem: { AnyView(tabItem($0)) },
                tabBarItem: { tabBarItem() },
                onTapped: { isRepeat in onTapped?(isRepeat) }
            )
        )

        if child.allItems.count == 1 {
            child.activeItem = child.allItems[0]
        }

        return self
    }

    /// Adds a coordinator as a tab, described for both hosts.
    @discardableResult
    func addTab<Output: Coordinatable, TabItem: View>(
        _ coordinator: Output,
        tabItem: @escaping (Bool) -> TabItem,
        tabBarItem: @escaping () -> UITabBarItem,
        onTapped: ((Bool, Output) -> Void)? = nil
    ) -> Output {
        if child.allItems == nil { child.allItems = [] }

        child.allItems.append(
            TabChildItem(
                presentable: coordinator,
                keyPathIsEqual: { _ in false },
                tabItem: { AnyView(tabItem($0)) },
                tabBarItem: { tabBarItem() },
                onTapped: { isRepeat in onTapped?(isRepeat, coordinator) }
            )
        )

        if child.allItems.count == 1 {
            child.activeItem = child.allItems[0]
        }

        return coordinator
    }

    /// Adds a view as a tab without a tab item (for custom tab bars).
    @discardableResult
    func addTab<Content: View>(_ view: Content) -> Self {
        addTab(view, tabItem: { _ in EmptyView() })
    }

    /// Adds a coordinator as a tab without a tab item (for custom tab bars).
    @discardableResult
    func addTab<Output: Coordinatable>(_ coordinator: Output) -> Output {
        addTab(coordinator, tabItem: { (_: Bool) in EmptyView() })
    }

    /// Selects the tab at the given index.
    func selectTab(_ index: Int) {
        child.activeTab = index
    }
}
