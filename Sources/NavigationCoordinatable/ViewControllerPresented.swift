import SwiftUI
import UIKit

@MainActor
public final class ViewControllerPresented {

    init(
        viewController: UIViewController? = nil,
        presentationType: PresentationType
    ) {
        self.presentationType = presentationType
        self.strongViewController = viewController
        self.weakViewController = viewController
    }

    var presentationType: PresentationType

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