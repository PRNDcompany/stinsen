//
//  UIKitIntrospectionViewController.swift
//  
//
//  Created by wani on 2022/04/25.
//

import SwiftUI


#if canImport(UIKit)
struct UIKitIntrospectionViewController<TargetViewControllerType: UIViewController>: UIViewControllerRepresentable {

    let selector: (UIViewController) -> TargetViewControllerType?
    let customize: (TargetViewControllerType) -> Void

    final class TargetCache {
        weak var target: TargetViewControllerType?
    }

    init(
        selector: @escaping (UIViewController) -> TargetViewControllerType?,
        customize: @escaping (TargetViewControllerType) -> Void
    ) {
        self.selector = selector
        self.customize = customize
    }

    func makeUIViewController(
        context: UIViewControllerRepresentableContext<UIKitIntrospectionViewController>
    ) -> IntrospectionUIViewController {
        let viewController = IntrospectionUIViewController()
        viewController.accessibilityLabel = "IntrospectionUIViewController<\(TargetViewControllerType.self)>"
        viewController.view.accessibilityLabel = "IntrospectionUIView<\(TargetViewControllerType.self)>"

        weak var coordinator = context.coordinator
        viewController.handler = { _viewController in
            self.findTargetView(_viewController, coordinator: coordinator)
        }
        return viewController
    }
    func findTargetView(_ uiViewController: IntrospectionUIViewController, coordinator: TargetCache?) {
        guard let target = selector(uiViewController), coordinator?.target != target else { return }
        coordinator?.target = target
        customize(target)
        uiViewController.handler = nil
    }

    func updateUIViewController(
        _ uiViewController: IntrospectionUIViewController,
        context: UIViewControllerRepresentableContext<UIKitIntrospectionViewController>
    ) {
        // Nothing to update
    }

    static func dismantleUIViewController(_ uiViewController: IntrospectionUIViewController, coordinator: Coordinator) {
        uiViewController.handler = nil
    }

    
    func makeCoordinator() -> TargetCache {
        TargetCache()
    }

}
#endif
