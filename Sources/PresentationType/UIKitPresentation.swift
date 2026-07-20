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

    public func makePresented<T: NavigationCoordinatable>(content: StackItemContent, nextId: Int, coordinator: T, onRemoved: @escaping () -> Void) -> ViewControllerPresented? {
        switch content {
        case .view:
            let view = AnyView(NavigationCoordinatableView(id: nextId, coordinator: coordinator))
            return ViewControllerPresented(
                viewController: makeViewController(content: view, onRemoved: onRemoved),
                presentationType: self,
                onRemoved: onRemoved
            )
        case .coordinator(let c):
            return ViewControllerPresented(
                viewController: makeViewController(content: c.view(), onRemoved: onRemoved),
                presentationType: self,
                onRemoved: onRemoved
            )
        }
    }

    public func makeViewController<Content>(content: Content) -> UIViewController where Content : View {
        makeViewController(content: content, onRemoved: {})
    }

    func makeViewController<Content: View>(content: Content, onRemoved: @escaping () -> Void) -> UIViewController {
        weak var dismissViewController: UIViewController?
        // Embed the removal observer inside the SwiftUI content so SwiftUI itself installs it
        // into the hosting hierarchy and forwards appearance callbacks to it. The notification
        // closure is injected right where the observer is made — no shared storage needed.
        let viewController = makeUIViewController(
            AnyView(content.background(RemovalDetectorView(onRemoved: onRemoved))),
            {
                guard let targetViewController = dismissViewController else { return }
                dismissed(viewController: targetViewController)
            }
        )
        dismissViewController = viewController
        return viewController
    }

    public func presented(parent: UIViewController, content: UIViewController) {

        // Removal detection is wired at creation time (makeViewController) — the ledger
        // observer already holds the once-guarded notification. Nothing to wire here.
        //
        // NOTE: 실험 격리 — dealloc 폴백(lifecycleObject) 비활성화 상태.
        // (배째로 dismiss되는 케이스 등은 이 상태에서 통지가 유실됨 — 격리 검증 목적)
        // 재활성 시: onDismissed는 present(item:)의 1회 가드 래퍼와 같은 인스턴스이므로 그대로 배선하면 됨.
        // if content.lifecycleObject != nil {
        //     content.lifecycleObject = nil
        // }
        // let lifecycleObject = LifecycleObject()
        // lifecycleObject.onDeinit = { onDismissed() }
        // content.lifecycleObject = lifecycleObject

        guard let typedContent = content as? ViewController else {
            assertionFailure("UIKitPresentation: expected \(ViewController.self), got \(type(of: content))")
            return
        }
        presentHandler(
            parent,
            typedContent
        )
    }

    public func dismissed(viewController: UIViewController) {
        // Do NOT notify or clear lifecycleObject here. Notification happens when the screen
        // has actually gone: the ledger observer fires at viewDidDisappear, and natural
        // deallocation fires the fallback. Clearing lifecycleObject at this point would
        // fire the completion before the dismissal even starts (the original bug).
        dismissHandler(viewController)
    }

}

// MARK: - private
// NOTE: 실험 격리 — dealloc 폴백(lifecycleObject) 관련 선언 전체 비활성화
// private enum MapTables {
//     static let lifecycle = WeakMapTable<UIViewController, Any>()
// }
//
// private nonisolated final class LifecycleObject {
//     var onDeinit: (() -> Void)?
//     deinit {
//         onDeinit?()
//     }
// }
//
// private extension UIViewController {
//     var lifecycleObject: LifecycleObject? {
//         get { MapTables.lifecycle.value(forKey: self) as? LifecycleObject }
//         set { MapTables.lifecycle.setValue(newValue, forKey: self) }
//     }
// }

