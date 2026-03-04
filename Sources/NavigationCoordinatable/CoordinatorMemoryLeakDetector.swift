import Foundation
import UIKit

/// Debug-only memory leak detector for coordinators
@MainActor
final class CoordinatorMemoryLeakDetector {
    static let shared = CoordinatorMemoryLeakDetector()
    
    private init() {}
    
    /// Track a coordinator that should be deallocated soon
    func trackCoordinator<T: Coordinatable>(_ coordinator: T, file: String, line: Int, function: String) {
        #if DEBUG
        // Store weak reference to check later
        weak var weakCoordinator = coordinator
        let coordinatorType = String(describing: type(of: coordinator))
        
        // Check after a delay to see if it was deallocated
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if weakCoordinator != nil {
                self?.showMemoryLeakAlert(
                    coordinatorType: coordinatorType,
                    file: file,
                    line: line,
                    function: function
                )
            }
        }
        #endif
    }
    
    private func showMemoryLeakAlert(coordinatorType: String, file: String, line: Int, function: String) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let message = """
        ⚠️ Memory Leak Detected!
        
        Coordinator: \(coordinatorType)
        Location: \(fileName):\(line)
        Function: \(function)
        
        This coordinator was popped but is still in memory after 2 seconds.
        Check for retain cycles or strong references.
        """
        
        // Show alert on iOS
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                let alert = UIAlertController(
                    title: "Memory Leak Detected",
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))

                // Find the topmost view controller
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }

                topController.present(alert, animated: true)
            }
        }
        #endif
    }
}

// Extension to make tracking easier
extension Coordinatable {
    /// Call this when a coordinator is being dismissed/popped to track potential memory leaks
    func trackForMemoryLeak(file: String = #file, line: Int = #line, function: String = #function) {
        #if DEBUG
        CoordinatorMemoryLeakDetector.shared.trackCoordinator(self, file: file, line: line, function: function)
        #endif
    }
}
