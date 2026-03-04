//
//  UIKitPresentation.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI



public struct UIKitPresentation<ViewController: UIViewController>: PresentationType {


    public typealias MakeUIViewControllerHandler = (_ content: AnyView, _ dismissHandler: @escaping () -> Void) -> ViewController
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
                // NOTE: Dismiss from presenting VC to close any presented VCs at once
                if viewController.presentedViewController != nil {
                    viewController.presentingViewController?.dismiss(animated: true)
                } else {
                    viewController.dismiss(animated: true)
                }
            }
        }
    }

    public func makePresented<T: NavigationCoordinatable>(content: StackItemContent, nextId: Int, coordinator: T) -> ViewControllerPresented? {
        switch content {
        case .view:
            let view = AnyView(NavigationCoordinatableView(id: nextId, coordinator: coordinator))
            return ViewControllerPresented(
                viewController: makeViewController(content: view),
                presentationType: self
            )
        case .coordinator(let c):
            return ViewControllerPresented(
                viewController: makeViewController(content: c.view()),
                presentationType: self
            )
        }
    }

    public func makeViewController<Content>(content: Content) -> UIViewController where Content : View {
        weak var dismissViewController: UIViewController?
        let viewController = makeUIViewController(AnyView(content), {
            guard let targetViewController = dismissViewController else { return }
            dismissed(viewController: targetViewController)
        })
        dismissViewController = viewController
        return viewController
    }

    public func presented(parent: UIViewController, content: UIViewController, onAppeared: @escaping () -> Void, onDismissed: @escaping () -> Void) {
        
        // Handle re-entry: clear existing lifecycleObject if present
        if content.lifecycleObject != nil {
            content.lifecycleObject = nil
        }

        let lifecycleObject = LifecycleObject()
        
        // Only call onDismissed when the view controller is actually being deallocated
        lifecycleObject.onDeinit = {
            onDismissed()
        }

        content.lifecycleObject = lifecycleObject
        guard let typedContent = content as? ViewController else {
            assertionFailure("UIKitPresentation: expected \(ViewController.self), got \(type(of: content))")
            return
        }
        presentHandler(
            parent,
            typedContent
        )
        
        // Call onAppeared after presentation completes
        // Note: The appear() function has been fixed to not trigger unwanted popTo() calls
        DispatchQueue.main.async {
            onAppeared()
        }
    }

    public func dismissed(viewController: UIViewController) {
        // Clear lifecycleObject to ensure clean state for re-entry
        viewController.lifecycleObject = nil
        
        // NOTE: We need to ensure the stack is properly cleaned up when dismissing
        // The dismissHandler should handle the UI dismissal, but the stack cleanup
        // should be handled by the coordinator through the onDismissed callback
        dismissHandler(viewController)
    }

}

// MARK: - private
private enum MapTables {
    static let lifecycle = WeakMapTable<UIViewController, Any>()
}

private final class LifecycleObject {
    var onDeinit: (() -> Void)?
    deinit {
        onDeinit?()
    }
}

private extension UIViewController {
    var lifecycleObject: LifecycleObject? {
        get { MapTables.lifecycle.value(forKey: self) as? LifecycleObject }
        set { MapTables.lifecycle.setValue(newValue, forKey: self) }
    }
}
