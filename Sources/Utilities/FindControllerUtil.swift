//  Copyright © 2026 PRND. All rights reserved.

#if canImport(UIKit)
import UIKit


enum FindControllerUtil {
    /// UIViewController의 부모 컨트롤러를 찾습니다.
    static func findParentController(of viewController: UIViewController) -> UIViewController? {
        if let parent = viewController.parent {
            return parent
        }

        // parent가 없으면 view hierarchy를 통해 찾기
        guard let superview = viewController.view.superview else {
            return nil
        }
        return findParentController(in: superview)
    }

    /// UIView의 responder chain을 따라 부모 컨트롤러를 찾습니다.
    static func findParentController(in view: UIView) -> UIViewController? {
        var responder = view.next

        while let currentResponder = responder {
            if let viewController = currentResponder as? UIViewController {
                return viewController
            }
            responder = currentResponder.next
        }

        return nil
    }
}
#endif
