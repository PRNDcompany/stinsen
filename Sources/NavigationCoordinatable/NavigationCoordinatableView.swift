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
private struct NavigationRootView<T: NavigationCoordinatable>: View {
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
@MainActor
final class DismissProxy: ChildDismissable {
    var dismissAction: DismissAction?


    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        dismissAction?()
        action?()
    }
}
