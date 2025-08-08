import SwiftUI

#if os(iOS)
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
        defer { strongViewController = nil }
        return weakViewController
    }
    
    private var strongViewController: UIViewController?
    private weak var weakViewController: UIViewController?
    
    func dismiss() {
        viewController.map {
            presentationType.dismissed(viewController: $0)
        }
    }
}
#else
// Placeholder for non-iOS platforms
public class ViewControllerPresented {
    // Empty implementation for non-iOS platforms
}
#endif