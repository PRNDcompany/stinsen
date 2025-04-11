//
//  UIKitIntrospectionViewController.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI


#if os(iOS)
struct UIKitIntrospectionViewController<TargetViewControllerType: UIViewController>: UIViewControllerRepresentable {

    let selector: (IntrospectionUIViewController) -> TargetViewControllerType?
    let customize: (TargetViewControllerType) -> Void

    public init(
        selector: @escaping (UIViewController) -> TargetViewControllerType?,
        customize: @escaping (TargetViewControllerType) -> Void
    ) {
        self.selector = selector
        self.customize = customize
    }

    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<UIKitIntrospectionViewController>
    ) -> IntrospectionUIViewController {
        let viewController = IntrospectionUIViewController()
        viewController.accessibilityLabel = "IntrospectionUIViewController<\(TargetViewControllerType.self)>"
        viewController.view.accessibilityLabel = "IntrospectionUIView<\(TargetViewControllerType.self)>"
        return viewController
    }
    
    public func updateUIViewController(
        _ uiViewController: IntrospectionUIViewController,
        context: UIViewControllerRepresentableContext<UIKitIntrospectionViewController>
    ) {
        findTargetView(in: uiViewController, maxAttempts: 3)
    }
    
    func findTargetView(
        in viewController: IntrospectionUIViewController,
        maxAttempts: Int
    ) {
        func attempt(_ remainingAttempts: Int) {
            DispatchQueue.main.async {
                if let targetView = self.selector(viewController) {
                    self.customize(targetView)
                } else if remainingAttempts > 0 {
                    attempt(remainingAttempts - 1)
                }
            }
        }
        
        attempt(maxAttempts)
    }
}
#endif
