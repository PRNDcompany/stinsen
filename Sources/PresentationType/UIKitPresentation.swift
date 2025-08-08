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
        
        // Handle re-entry: clear existing lifeCicleObject if present
        if content.lifeCicleObject != nil {
            content.lifeCicleObject = nil
        }

        let lifeCicleObject = LifeCicleObject()
        
        // Only call onDissmissed when the view controller is actually being deallocated
        lifeCicleObject.onDeinit = {
            onDissmissed()
        }

        content.lifeCicleObject = lifeCicleObject
        presentHandler(
            parent,
            content as! ViewController
        )
        
        // Call onAppeared after presentation completes
        // Note: The appear() function has been fixed to not trigger unwanted popTo() calls
        DispatchQueue.main.async {
            onAppeared()
        }
    }

    public func dismissed(viewController: UIViewController) {
        // Clear lifeCicleObject to ensure clean state for re-entry
        viewController.lifeCicleObject = nil
        
        // NOTE: We need to ensure the stack is properly cleaned up when dismissing
        // The dismissHandler should handle the UI dismissal, but the stack cleanup
        // should be handled by the coordinator through the onDissmissed callback
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
