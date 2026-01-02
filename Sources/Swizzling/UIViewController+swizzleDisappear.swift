//
//  UIViewController+swizzleDisappear.swift
//  Stinsen
//
//  Created by wani on 2023/08/14.
//

import UIKit

// MARK: - private
private enum MapTables {
    static let willDismiss = WeakMapTable<UIViewController, (() -> Void)>()
    static let didDismiss = WeakMapTable<UIViewController, (() -> Void)>()
    static let isDismissed = WeakMapTable<UIViewController, Bool>()
}

extension UIViewController {

    private var isDismissed: Bool {
        get { MapTables.isDismissed.value(forKey: self) ?? false }
        set { MapTables.isDismissed.setValue(newValue, forKey: self) }
    }

    var onWillDismiss: (() -> Void)? {
        get { MapTables.willDismiss.value(forKey: self) }
        set { MapTables.willDismiss.setValue(newValue, forKey: self) }
    }

    var onDidDismiss: (() -> Void)? {
        get { MapTables.didDismiss.value(forKey: self) }
        set { MapTables.didDismiss.setValue(newValue, forKey: self) }
    }
}


extension UIViewController {

    static let swizzleDisappear: Void = {
        _ = swizzleViewWillDisappear
        _ = swizzleViewDidDisappear
    }()

    private static let swizzleViewWillDisappear: Void = {
        let originalSelector = #selector(viewWillDisappear(_:))
        let swizzledSelector = #selector(swizzled_viewWillDisappear(_:))

        let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector)

        method_exchangeImplementations(originalMethod!, swizzledMethod!)
    }()

    private static let swizzleViewDidDisappear: Void = {
        let originalSelector = #selector(viewDidDisappear(_:))
        let swizzledSelector = #selector(swizzled_viewDidDisappear(_:))

        let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector)

        method_exchangeImplementations(originalMethod!, swizzledMethod!)
    }()

    @objc private func swizzled_viewWillDisappear(_ animated: Bool) {
        swizzled_viewWillDisappear(animated)
        guard isBeingDismissed || isMovingFromParent else { return }
        isDismissed = true
        onWillDismiss?()
    }

    @objc private func swizzled_viewDidDisappear(_ animated: Bool) {
        swizzled_viewDidDisappear(animated)
        guard isDismissed else { return }
        onDidDismiss?()
    }
}
