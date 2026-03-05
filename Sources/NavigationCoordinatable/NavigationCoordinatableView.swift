import Foundation
import SwiftUI
import Combine


struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    private let id: Int
    private let router: NavigationRouter<T>
    @StateObject var presentationHelper: PresentationHelper<T>
    @ObservedObject var root: NavigationRoot

    var start: AnyView?

    var body: some View {
        commonView
            .environmentObject(router)
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

        self.router = NavigationRouter(
            id: id,
            coordinator: coordinator.routerStorable
        )

        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }

        self.root = coordinator.stack.root

        RouterStore.shared.store(router: router)

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
    let coordinator: T

    var body: some View {
        ZStack {
            slot(root.activeSlot)
        }
        .onChange(of: root.pendingSlot) { id in
            root.activeSlot = id ?? 0
        }
        .animation(root.pendingAnimation, value: root.activeSlot)
    }

    @ViewBuilder
    private func slot(_ index: Int) -> some View {
        let _ = print("wani.root.slotTransitions[index]", root.slotTransitions[index])
        
        if let item = root.slots[index] {
            AnyView(item.child.view())
                .zIndex(root.slotZIndex[index])
                .transition(root.slotTransitions[index])
        }
    }

}
