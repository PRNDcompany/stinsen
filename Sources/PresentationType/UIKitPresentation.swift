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
            return .viewController(
                ViewControllerPresented(
                    viewController: makeViewController(content: view),
                    presentationType: self
                )
            )
        } else {
            return .viewController(
                ViewControllerPresented(
                    viewController: makeViewController(content: presentable.view()),
                    presentationType: self
                )
            )
        }
    }

    public func makeViewController<Content>(content: Content) -> UIViewController where Content : View {
        weak var dismissViewController: UIViewController!
        let viewController = makeUIViewController(AnyView(content), {
            dismissed(viewController: dismissViewController)
        })
        dismissViewController = viewController
        return viewController
    }

    public func presented(parent: UIViewController, content: UIViewController, onAppeared: @escaping () -> Void, onDissmissed: @escaping () -> Void) {
        guard content.lifeCicleObject == nil else { return }

        let lifeCicleObject = LifeCicleObject()
        lifeCicleObject.onDeinit = {
            onDissmissed()
            onAppeared()
        }

        content.lifeCicleObject = lifeCicleObject

        presentHandler(
            parent,
            content as! ViewController
        )

    }

    public func dismissed(viewController: UIViewController) {
        dismissHandler(viewController)
    }

}
#endif


// MARK: - private
private enum MapTables {
    static let lifeCicle = WeakMapTable<UIViewController, Any>()
}

private final class LifeCicleObject {
    var onDeinit: (() -> Void)?
    deinit {
        onDeinit?()
    }
}

private extension UIViewController {
    var lifeCicleObject: LifeCicleObject? {
        get { MapTables.lifeCicle.value(forKey: self) as? LifeCicleObject }
        set { MapTables.lifeCicle.setValue(newValue, forKey: self) }
    }
}
