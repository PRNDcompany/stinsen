import Foundation
import SwiftUI
import Combine


struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    private let id: Int
    private let router: NavigationRouter<T>
    @StateObject var presentationHelper: PresentationHelper<T>
    @StateObject var root: NavigationRoot
    
    var start: AnyView?
    
    var body: some View {
        commonView
            .environmentObject(router)
    }
    
    
    @ViewBuilder
    var rootView: some View {
        if  id == -1 {
            AnyView(coordinator.customize(AnyView(root.item.child.view())))
        } else if let start = self.start {
            start
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    var commonView: some View {
        rootView
            .present(
                presented: presentationHelper.presented,
                onAppear: { coordinator.appear(id) },
                onDismiss: {
                    coordinator.stack.dismissalAction[id]?()
                    coordinator.stack.dismissalAction[id] = nil
                }
            )
            .background(navigationLink)
            .background(sheet)
    }
    
    var navigationLink: some View {
        NavigationLink(
            destination: { () -> AnyView in
                if let view = presentationHelper.presented?.view {
                    return AnyView(view.onDisappear {
                        coordinator.stack.dismissalAction[id]?()
                        coordinator.stack.dismissalAction[id] = nil
                    })
                } else {
                    return AnyView(EmptyView())
                }
            }(),
            isActive: Binding<Bool>(
                get: { presentationHelper.presented?.type is PushPresentation },
                set: { _ in coordinator.appear(id) }
            ),
            label: { // Zero View 필요
                Color.white.frame(width: 0, height: 0)
            }
        )
        .hidden()
        .background(osBugHelperView)
    }
    
    var sheet: some View {
        Color.clear
            .hidden()
            .sheet(
                isPresented: Binding<Bool>(
                    get: { presentationHelper.presented?.type is ModalPresentation },
                    set: { _ in coordinator.appear(id) }
                ),
                onDismiss: {
                    coordinator.stack.dismissalAction[id]?()
                    coordinator.stack.dismissalAction[id] = nil
                },
                content: { () -> AnyView in
                    return { () -> AnyView in
                        if let view = presentationHelper.presented?.view {
                            return AnyView(view)
                        } else {
                            return AnyView(EmptyView())
                        }
                    }()
                })
    }
    
    init(id: Int, coordinator: T) {
        self.id = id
        self.coordinator = coordinator
        
        self.router = NavigationRouter(
            id: id,
            coordinator: coordinator.routerStorable
        )
        
        if coordinator.stack.root == nil {
            coordinator.setupRoot()
        }

        let helper = PresentationHelper(id: id, coordinator: coordinator)
        self._presentationHelper = StateObject(wrappedValue: helper)
        self._root = StateObject(wrappedValue: coordinator.stack.root)
        
        RouterStore.shared.store(router: router)
        
        if let presentation = coordinator.stack.value[safe: id] {
            if let view = presentation.presentable as? AnyView {
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

extension NavigationCoordinatableView {
    /// NOTE: iOS 14 bug `https://stackoverflow.com/questions/66559814/swiftui-navigationlink-pops-out-by-itself`
    var osBugHelperView: some View {
        NavigationLink(destination: EmptyView()) { EmptyView() }.hidden()
    }
}



// MARK: - uikit present
extension View {
    func present(presented: Presented?, onAppear: @escaping () -> Void, onDismiss: @escaping () -> Void) -> some View {
#if os(iOS)
        background(UIKitIntrospectionViewController(selector: { $0.parent }) { viewController in
            guard case let .viewController(uiKitPresented) = presented else { return }

            guard let destination = uiKitPresented.viewController else {
                return
            }
            uiKitPresented.presentationType.presented(
                parent: viewController,
                content: destination,
                onAppeared: onAppear,
                onDissmissed: onDismiss
            )
        })
#else
        self
#endif
    }
}
