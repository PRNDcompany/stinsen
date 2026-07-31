import SwiftUI
import UIKit

struct RemovalDetectorView: UIViewControllerRepresentable {
    let onRemoved: () -> Void

    func makeUIViewController(context: Context) -> RemovalObserverViewController {
        RemovalObserverViewController(onRemoved: onRemoved)
    }

    func updateUIViewController(_ uiViewController: RemovalObserverViewController, context: Context) { }
}


final class RemovalObserverViewController: UIViewController {
    var onRemoved: (() -> Void)?

    private var initialSnapshot: ContainmentSnapshot?

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard initialSnapshot == nil, let parent else { return }
        initialSnapshot = ContainmentSnapshot(parent: parent)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let parent, let initialSnapshot else { return }
        guard ContainmentSnapshot(parent: parent) != initialSnapshot else { return }

        guard let onRemoved else { return }
        onRemoved()
        self.onRemoved = nil
    }
}


private struct ContainmentSnapshot: Equatable {
    let hasNavigationController: Bool
    let hasPresentingViewController: Bool

    init(parent: UIViewController) {
        hasNavigationController = parent.navigationController != nil
        hasPresentingViewController = parent.presentingViewController != nil
    }
}
