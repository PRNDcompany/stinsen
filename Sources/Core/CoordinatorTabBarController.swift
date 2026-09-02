import Combine
import UIKit

/// A `TabCoordinatable`'s tabs as UIKit sees them.
///
/// The SwiftUI `TabView` rendering is untouched and still the answer for a SwiftUI app.
/// This is the same tabs, the same `TabChild` state, driven by a real
/// `UITabBarController` — because a UIKit app hosting a SwiftUI `TabView` gets a tab bar
/// that is not its own: no `UITabBarItem` to configure, no delegate to hook, nothing the
/// rest of a UIKit app can reach.
///
/// Selection is kept in step in both directions. `TabChild.activeTab` is the model, and
/// it is written by both sides — `focusFirst`, `selectTab`, and the user tapping a tab —
/// so each direction guards against echoing the other back.
@MainActor
final class CoordinatorTabBarController: UITabBarController, ScreenLifecycleReporting {

    /// Strong on purpose: this view controller *is* the coordinator's UIKit
    /// representation, so it has to keep it alive the way the SwiftUI view does.
    ///
    /// Without it `MyTabCoordinator().viewController()` hands back a controller whose
    /// coordinator is already gone, and the tab item closures — which capture the
    /// coordinator `unowned` — trap the moment the tabs are installed. Measured: the
    /// example app died with `EXC_BREAKPOINT` on the first presentation.
    private let coordinator: any Coordinatable

    private let child: TabChild
    private var subscription: AnyCancellable?

    let screenLifecycleReporter = ScreenLifecycleReporter()

    /// Set while responding to the other side, so a change does not bounce back.
    private var isSyncing = false

    init(coordinator: any Coordinatable, child: TabChild) {
        self.coordinator = coordinator
        self.child = child
        super.init(nibName: nil, bundle: nil)
        // Set up here rather than in `viewDidLoad`, because by then a lifecycle probe may
        // already have been added as a child — and assigning `viewControllers` replaces
        // the children a tab bar controller manages, taking the probe with it.
        delegate = self
        installTabs()
        observeSelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Appearance reporting
    //
    // A library-owned container can report itself. This avoids adding an invisible child
    // that `UITabBarController` would not forward to anyway, and avoids loading the tab bar
    // controller merely to attach that child's view before it is presented.

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        screenLifecycleReporter.viewWillAppear(self, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        screenLifecycleReporter.viewDidAppear(self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        screenLifecycleReporter.viewWillDisappear(self, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        screenLifecycleReporter.viewDidDisappear(self, animated: animated)
    }

    private func installTabs() {
        let items = child.allItems ?? []
        viewControllers = items.map { item in
            let screen = item.presentable.viewController()
            if let barItem = item.tabBarItem() {
                // The declaration wins: the parent decides how a child is presented, and a
                // tab item is part of that. A child that also set one in `configure(_:)`
                // loses here, which is the right way round.
                screen.tabBarItem = barItem
            } else if screen.tabBarItem.title == nil, screen.tabBarItem.image == nil {
                // Nothing declared *and* nothing the child set for itself. Checked rather
                // than assumed, because a coordinator tab can supply its own item from
                // `configure(_:)` — warning about a blank tab that is not blank is worse
                // than saying nothing.
                warnAboutMissingTabBarItem(for: screen)
            }
            return screen
        }
        if items.indices.contains(child.activeTab) {
            selectedIndex = child.activeTab
        }
    }

    /// A tab with no `UITabBarItem` still appears — UIKit gives it an empty one — so
    /// without saying something the result is a tab bar of blank entries and no clue why.
    private func warnAboutMissingTabBarItem(for screen: UIViewController) {
        #if DEBUG
        print("""
            Stinsen: the tab showing \(type(of: screen)) was declared with a SwiftUI \
            `tabItem:` only, so there is nothing to build a UITabBarItem from and it will \
            appear blank. Declare it with `tabBarItem:` as well to use this coordinator \
            through `viewController()`, or have the tab set its own in `configure(_:)`.
            """)
        #endif
    }

    private func observeSelection() {
        subscription = child.activeTabDidChange.sink { [weak self] index in
            guard let self, !self.isSyncing else { return }
            guard self.viewControllers?.indices.contains(index) == true else { return }
            self.isSyncing = true
            self.selectedIndex = index
            self.isSyncing = false
        }
    }
}

extension CoordinatorTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard !isSyncing, let index = viewControllers?.firstIndex(of: viewController) else { return }
        isSyncing = true
        // Assigned unconditionally, including when it is already the active tab: that is
        // what makes "tapped the tab I am already on" observable, which is how a tab
        // coordinator is told to pop its flow back to the start.
        child.activeTab = index
        isSyncing = false
    }
}
