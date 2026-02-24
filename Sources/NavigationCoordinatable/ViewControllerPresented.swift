import SwiftUI

#if canImport(UIKit)
public final class ViewControllerPresented {
    
    init(
        viewController: UIViewController? = nil,
        presentationType: UIKitPresentationType
    ) {
        self.presentationType = presentationType
        self.strongViewController = viewController
        self.weakViewController = viewController
    }
    
    var presentationType: UIKitPresentationType
    
    var viewController: UIViewController? {
        return weakViewController
    }

    private var strongViewController: UIViewController?
    private weak var weakViewController: UIViewController?

    /// Release the strong reference after the VC has been retained by the view hierarchy
    func releaseStrongReference() {
        strongViewController = nil
    }

    func dismiss() {
        guard let vc = weakViewController else { return }
        presentationType.dismissed(viewController: vc)
    }
}
#else
// Placeholder for non-iOS platforms
public class ViewControllerPresented {
    // Empty implementation for non-iOS platforms
}
#endif