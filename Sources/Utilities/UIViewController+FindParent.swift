//  Copyright © 2025 PRND. All rights reserved.
import UIKit


extension UIViewController {
    func findParent() -> UIViewController? {
        guard let parent else {
            return view.superview?.findParentViewController()
        }
        return parent
    }
}


private extension UIView {
    func findParentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
}
