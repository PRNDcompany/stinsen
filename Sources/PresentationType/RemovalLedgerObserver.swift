import SwiftUI
import UIKit

/// Detects that the screen it is embedded in has actually left the view hierarchy.
///
/// Embedded into the screen's SwiftUI content via `RemovalLedgerObserverBridge`, so SwiftUI
/// installs it into the hosting hierarchy itself (adding subviews to `UIHostingController.view`
/// directly is unsupported) and forwards appearance callbacks down to it.
///
/// Judgment happens at `viewDidDisappear` against persistent, chain-derived state instead of
/// UIKit's removal flags — the flags are set only around the removed view controller's own
/// callback invocation and read `false` from any relayed child (verified empirically):
/// - popped: the parent link to its `UINavigationController` is severed and stays severed
/// - dismissed: the `presentingViewController` chain is severed and stays severed
/// - merely covered by another screen: both links remain intact
///
/// Known limitation (by design): a screen inside a navigation controller that gets dismissed
/// wholesale keeps its navigation link, so this observer stays silent there — as do screens
/// that never receive appearance callbacks at all (covered screens inside a dismissed ancestor,
/// views that never appeared). The deallocation fallback in `UIKitPresentation.presented()`
/// covers those paths.


/// SwiftUI bridge that installs the observer into the screen's content hierarchy.
struct RemovalDetectorView: UIViewControllerRepresentable {
    let onRemoved: () -> Void

    func makeUIViewController(context: Context) -> RemovalObserverViewController {
        RemovalObserverViewController(onRemoved: onRemoved)
    }

    func updateUIViewController(_ uiViewController: RemovalObserverViewController, context: Context) { }
}


final class RemovalObserverViewController: UIViewController {
    /// One-shot: consumed and discarded on the first removal detection.
    var onRemoved: (() -> Void)?
    
    init(onRemoved: @escaping () -> Void) {
        super.init(nibName: nil, bundle: nil)
        self.onRemoved = onRemoved
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isHidden = true
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Without a parent the host cannot be judged (observer already detached) — stay silent
        // and let the deallocation fallback take over.
        guard onRemoved != nil, let host = parent else { return }

        let isPopped = host.navigationController == nil
        let isDismissed = host.presentingViewController == nil
        guard isPopped, isDismissed else { return }

        guard let onRemoved else { return }
        onRemoved()
        self.onRemoved = nil
    }
}
