import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Debug-only memory leak detector for coordinators
final class CoordinatorMemoryLeakDetector {
    static let shared = CoordinatorMemoryLeakDetector()
    
    private init() {}
    
    /// Track a coordinator that should be deallocated soon
    func trackCoordinator<T: Coordinatable>(_ coordinator: T, file: String = #file, line: Int = #line) {
        #if DEBUG
        // Store weak reference to check later
        weak var weakCoordinator = coordinator
        let coordinatorId = coordinator.id
        let coordinatorType = String(describing: type(of: coordinator))
        
        // Check after a delay to see if it was deallocated
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if weakCoordinator != nil {
                self?.showMemoryLeakAlert(
                    coordinatorType: coordinatorType,
                    coordinatorId: coordinatorId,
                    file: file,
                    line: line
                )
            }
        }
        #endif
    }
    
    private func showMemoryLeakAlert(coordinatorType: String, coordinatorId: String, file: String, line: Int) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let message = """
        ⚠️ Memory Leak Detected!
        
        Coordinator: \(coordinatorType)
        ID: \(coordinatorId)
        Location: \(fileName):\(line)
        
        This coordinator was popped but is still in memory after 2 seconds.
        Check for retain cycles or strong references.
        """
        
        print("[MEMORY LEAK] \(message)")
        
        #if canImport(UIKit)
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
        
        // Also trigger assertion for debugging
        assertionFailure("Memory leak detected: \(coordinatorType) with id \(coordinatorId) was not deallocated after being popped")
        #endif
    }
}

// Extension to make tracking easier
extension Coordinatable {
    /// Call this when a coordinator is being dismissed/popped to track potential memory leaks
    func trackForMemoryLeak() {
        #if DEBUG
        CoordinatorMemoryLeakDetector.shared.trackCoordinator(self)
        #endif
    }
}