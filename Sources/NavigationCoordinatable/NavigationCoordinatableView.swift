import Foundation
import SwiftUI
import Combine


/// A coordinator's root screen, and the anchor its later screens hang off.
///
/// There is one of these per coordinator now, not one per stack level. Levels used to
/// recurse — each presented screen was wrapped in another `NavigationCoordinatableView`
/// carrying the next depth index — because in the SwiftUI implementation each level
/// genuinely was a separate view value with no identity of its own. Over UIKit the
/// presented view controllers *are* the levels, so the recursion (and the index it
/// existed to carry) is gone.
struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    @ObservedObject var root: NavigationRoot

    var body: some View {
        coordinator
            .customize(AnyView(
                NavigationRootView(
                    root: root,
                    coordinator: coordinator
                )
            ))
            // The introspection view controller *is* the anchor — it is not used to go
            // looking for someone else's.
            //
            // Walking up to the enclosing controller made the anchor whatever view
            // controller happened to contain this coordinator's root view, which is not
            // the coordinator's own: dropping a coordinator into an ordinary SwiftUI
            // hierarchy —
            //
            //     VStack { Text("…"); ChildCoordinator().view() }
            //
            // — gives the child the *same* anchor as its parent, and with it the
            // parent's probe and the parent's idea of what is in front. A representable
            // already gets a view controller of its own, one per coordinator, so there
            // is nothing to search for.
            //
            // It works as an anchor because containment resolves through it:
            // `navigationController` reads through ancestors, `present` forwards to the
            // nearest controller defining a presentation context, and
            // `navigationStackEntry` finds the ancestor the navigation controller
            // actually holds.
            .background(UIKitIntrospectionViewController(selector: { $0 }) {
                coordinator.host.bind(base: $0)
            })
    }

    init(coordinator: T) {
        self.coordinator = coordinator

        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }

        self.root = coordinator.stack.root
    }
}


// MARK: - NavigationRootView

/// Renders the two-slot root view with animated transitions.
///
/// Two-slot design is intentional: each slot independently holds its own
/// NavigationRootItem, preventing the "two B views" bug that a single
/// .id()-based approach causes. The onChange two-phase commit ensures
/// SwiftUI applies the removal transition on the visible slot before
/// swapping activeSlot.
struct NavigationRootView<T: NavigationCoordinatable>: View {
    @ObservedObject var root: NavigationRoot
    @StateObject var context = Context()

    let coordinator: T

    @Environment(\.dismiss) var dismissAction

    var body: some View {
        ZStack {
            slotView
        }
        .onAppear {
            guard coordinator.stack.parent == nil else { return }
            context.dismissProxy.dismissAction = dismissAction
            // `host`는 지금(onAppear 시점)이 아니라 나중에 실제로 dismiss가 호출되는
            // 시점에 base를 읽는다 — introspection VC의 바인딩이 이 onAppear보다
            // 늦게 끝날 수 있어서, 참조 그 자체(host)를 넘기고 base는 lazy하게 조회한다.
            context.dismissProxy.host = coordinator.host
            coordinator.stack.parent = context.dismissProxy
        }
    }

    @ViewBuilder
    var slotView: some View {
        if let slot = root.activeSlot {
            slot.item.child.view()
                .zIndex(slot.zIndex)
                .transition(slot.transition)
        }
    }

    @MainActor
    final class Context: ObservableObject {
        let dismissProxy = DismissProxy()
    }
}



/// Lightweight ChildDismissable that wraps SwiftUI's DismissAction.
/// Used as fallback parent when a coordinator has no real parent (e.g., root modal).
///
/// SwiftUI's `DismissAction` only understands two things: its own declarative
/// presentation graph (`.sheet`, `NavigationStack`, …), and one hop into raw UIKit —
/// "was my own hosting controller itself presented?" It cannot see through an extra
/// UIKit layer, such as being installed as the *root* of a `UINavigationController`
/// that was itself presented rather than pushed. In that shape, `self` was never
/// pushed (nothing to pop to) and was never presented (the nav was), so `dismiss()`
/// finds nothing to act on and silently does nothing.
///
/// `host` gives this a second, UIKit-native way to answer the same question: walk the
/// coordinator's own anchor (`host.base`) up to its `navigationController` and check
/// whether that nav's root is `base` and whether the nav itself was presented. When
/// both hold, dismissing the nav's presenter is the correct action and SwiftUI's
/// `dismiss()` would not have found it. Every other shape (pushed with something below
/// it, or presented directly) is already handled correctly by `dismissAction`, so this
/// is additive rather than a replacement.
@MainActor
final class DismissProxy: ChildDismissable {
    var dismissAction: DismissAction?
    weak var host: NavigationHost?

    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        if let base = host?.base,
           let navigationController = base.navigationController,
           navigationController.viewControllers.first === base,
           let presenting = navigationController.presentingViewController {
            presenting.dismiss(animated: true, completion: action)
            return
        }
        dismissAction?()
        action?()
    }
}
