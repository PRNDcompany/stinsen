//
//  UIKitPresentation.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI



#if os(iOS)
public struct UIKitPresentation<ViewController: UIViewController>: UIKitPresentationType {

    public typealias MakeUIViewControllerHandler = (_ content: AnyView, _ dissmissHandler: @escaping () -> Void) -> ViewController
    public typealias DismissHandler = (_ viewController: UIViewController) -> Void
    public typealias PresentHandler = (_ parent: UIViewController, _ viewController: ViewController) -> Void


    var makeUIViewController: MakeUIViewControllerHandler
    var presentHandler: PresentHandler
    var dismissHandler: DismissHandler

    public init(make makeUIViewController: @escaping MakeUIViewControllerHandler,
                present presentHandler: @escaping PresentHandler,
                dismiss dismissHandler: @escaping DismissHandler) {
        self.makeUIViewController = makeUIViewController
        self.presentHandler = presentHandler
        self.dismissHandler = dismissHandler
    }

    public init(make makeUIViewController: @escaping MakeUIViewControllerHandler,
                present presentHandler: @escaping PresentHandler) {
        self.makeUIViewController = makeUIViewController
        self.presentHandler = presentHandler
        self.dismissHandler = { viewController in
            if let navigationController = viewController.navigationController,
               navigationController.viewControllers.count > 2 {
                viewController.navigationController?.popViewController(animated: true)
            } else {
                // NOTE: - 위에 띄워둔게 있을 경우 한번에 닫히기 위해서
                if viewController.presentedViewController != nil {
                    viewController.presentingViewController?.dismiss(animated: true)
                } else {
                    viewController.dismiss(animated: true)
                }
            }
        }
    }

    public func makePresented<T: NavigationCoordinatable>(presentable: ViewPresentable, nextId: Int, coordinator: T) -> Presented {
        if presentable is AnyView {
            let view = AnyView(NavigationCoordinatableView(id: nextId, coordinator: coordinator))
            
            return Presented(
                view: view,
                type: self
            )
        } else {
            return Presented(
                view: presentable.view(),
                type: self
            )
        }
    }

    public func presented<Content: View>(
        parent: UIViewController,
        content: Content?,
        onAppeared: @escaping () -> Void,
        onDissmissed: @escaping () -> Void
    ) {
        guard let content = content else {
            return
        }

        let viewController = makeUIViewController(content: content)
        let lifeCicleView = LifeCicleView()
        lifeCicleView.onDeinit = {
            onDissmissed()
            onAppeared()
        }
        viewController.view.insertSubview(lifeCicleView, at: 0)

        presentHandler(
            parent,
            viewController
        )
        
    }

    public func dismissed(viewController: UIViewController) {
        dismissHandler(viewController)
    }


    private func makeUIViewController<Content: View>(content: Content) -> ViewController {
        weak var dismissViewController: UIViewController!
        let viewController = makeUIViewController(AnyView(content), {
            dismissed(viewController: dismissViewController)
        })
        dismissViewController = viewController
        return viewController
    }
}
#endif


private final class LifeCicleView: UIView {
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
