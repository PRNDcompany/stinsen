import Foundation
import SwiftUI
import Combine


struct NavigationCoordinatableView<T: NavigationCoordinatable>: View {
    var coordinator: T
    private let id: Int
    private let router: NavigationRouter<T>
    @ObservedObject var presentationHelper: PresentationHelper<T>
    @ObservedObject var root: NavigationRoot
    
    @State var isUIKitPresented: UIKitPresentationType?
    
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
                isUIKitPresented: $isUIKitPresented,
                presented: presentationHelper.presented,
                appear: { coordinator.appear(id) },
                dismissalAction: {
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
        self.presentationHelper = PresentationHelper(
            id: self.id,
            coordinator: coordinator
        )
        
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
    func present(isUIKitPresented: Binding<UIKitPresentationType?>, presented: Presented?, appear: @escaping () -> Void, dismissalAction: @escaping () -> Void) -> some View {
#if os(iOS)
        background(UIKitIntrospectionViewController(selector: { $0.parent }) { viewController in
            guard let presentationType = presented?.type as? UIKitPresentationType,
                  let content = presented?.view else {
                if isUIKitPresented.wrappedValue != nil {
                    // NOTE: - Coordinator 로 popLast 호출될 때 dissmiss 가 필요.
                    isUIKitPresented.wrappedValue?.dismissed(parent: viewController)
                    isUIKitPresented.wrappedValue = nil
                }
                return
            }
            
            isUIKitPresented.wrappedValue = presentationType
            
            // navigationPush 가 일어나면 onDisapper가 이미 발생함.
            presentationType.presented(
                parent: viewController,
                content: content
                    .onDisappear { [weak viewController] in
                        // NOTE: - presentedViewController 사라지면 dissmiss 완료
                        guard viewController?.presentedViewController == nil else {
                            let lifeCicleView = LifeCicleView()
                            lifeCicleView.onDeinit = {
                                appear()
                                dismissalAction()
                            }
                            viewController?.presentedViewController?.view.insertSubview(lifeCicleView, at: 0)
                            return
                        }
                        // NOTE: - appear, dismissalAction 시점 변화가 필요할지도 모르겠다.
                        // presented: Presented 부분을 Binding으로 변경해야할 가능성도 있음 기존 NavigationLink, sheet 와 비슷하게
                        appear()
                        dismissalAction()
                    }
            )
        })
#else
        self
#endif
    }
}

private class LifeCicleView: UIView {
    var onDeinit: (() -> Void)?
    
    deinit {
        onDeinit?()
    }
    
    required init() {
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
