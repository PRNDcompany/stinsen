import Foundation
import SwiftUI
import Combine


struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    private let id: Int
    @StateObject var presentationHelper: PresentationHelper<T>
    @ObservedObject var root: NavigationRoot

    var start: AnyView?

    var body: some View {
        commonView
    }


    @ViewBuilder
    var rootView: some View {
        if id == -1 {
            coordinator
                .customize(AnyView(
                    NavigationRootView(
                        root: root,
                        coordinator: coordinator
                    )
                ))
        } else if let start = self.start {
            start
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    var commonView: some View {
        rootView
            .background(UIKitIntrospectionViewController(
                selector: { FindControllerUtil.findParentController(of: $0) }
            ) {
                presentationHelper.setupViewController($0)
            })
    }

    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        self._presentationHelper = StateObject(wrappedValue: {
            PresentationHelper(
                id: id,
                coordinator: coordinator
            )
        }())

        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }

        self.root = coordinator.stack.root

        if let presentation = coordinator.stack.value[safe: id] {
            if case .view(let view) = presentation.content {
                self.start = view
            } else {
                fatalError("Can only show views")
            }
        } else if id == -1 {
            self.start = nil
        } else {
            fatalError()
        }
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
        .background {
            RemovalDetectorView(onRemoved: context.dismissProxy.completeDismissal)
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


@MainActor
final class DismissProxy: ChildDismissable {
    var dismissAction: DismissAction?

    private var onDismissed: (() -> Void)?

    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        onDismissed = action
        dismissAction?()
    }

    func completeDismissal() {
        guard let onDismissed else { return }
        self.onDismissed = nil
        onDismissed()
    }
}
