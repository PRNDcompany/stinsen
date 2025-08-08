import Foundation

@propertyWrapper public struct RouterObject<Value: Routable> {
    private var storage: RouterStore
    private var retreived: Value?
    
    public var wrappedValue: Value? {
        mutating get {
            guard let currentValue: Value = self.retreived else {
                self.retreived = storage.retrieve()
                return self.retreived
            }
            return currentValue
        }
        @available(*, unavailable, message: "RouterObject cannot be set") set {
            fatalError()
        }
    }
    
    public init() {
        self.storage = RouterStore.shared
    }
}

public class RouterStore {
    public static let shared = RouterStore()
    
    // Use WeakMapTable for better memory management
    private let routerTable = WeakMapTable<AnyObject, AnyObject>()
    private var routerOrder: [WeakRef<AnyObject>] = []
    private let lock = NSRecursiveLock()
    
    private init() {}
}

public extension RouterStore {
    func store<T: Routable>(router: T) {
        lock.lock()
        defer { lock.unlock() }
        
        // Clean up nil references
        cleanupRouterStore()
        
        // Store in WeakMapTable using router itself as key
        // This allows automatic cleanup when router is deallocated
        routerTable.setValue(router as AnyObject, forKey: router as AnyObject)
        
        // Also maintain order for LIFO retrieval
        let ref = WeakRef<AnyObject>(value: router)
        routerOrder.insert(ref, at: 0)
    }
    
    func retrieve<T: Routable>() -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        // Search through ordered routers for type match
        // WeakMapTable automatically cleans up deallocated routers
        for routerRef in routerOrder {
            if let router = routerRef.value as? T {
                // Verify it's still in the table (not deallocated)
                if routerTable.value(forKey: router as AnyObject) != nil {
                    return router
                }
            }
        }
        
        return nil
    }
    
    /// Removes all nil weak references
    private func cleanupRouterStore() {
        routerOrder = routerOrder.filter { $0.value != nil }
    }
}
