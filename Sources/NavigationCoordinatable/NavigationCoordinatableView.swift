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
            ZStack {
                if root.activeSlot == 0, let slotItem = root.slots[0] {
                    AnyView(coordinator.customize(AnyView(slotItem.child.view())))
                        .zIndex(root.slotZIndex[0])
                        .transition(root.slotTransitions[0])
                }
                if root.activeSlot == 1, let slotItem = root.slots[1] {
                    AnyView(coordinator.customize(AnyView(slotItem.child.view())))
                        .zIndex(root.slotZIndex[1])
                        .transition(root.slotTransitions[1])
                }
            }
            .onChange(of: root.pendingTransitionId) { id in
                guard id != nil,
                      let animation = root.pendingAnimation,
                      let newItem = root.pendingItem else { return }
                withAnimation(animation) {
                    root.item = newItem
                    root.activeSlot = root.pendingSlot
                    root.pendingTransitionId = nil
                }
            }
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

