import Foundation

@propertyWrapper public struct RouterObject<Value: Routable> {
    private var storage: RouterStore
    private var retrieved: Value?
    
    public var wrappedValue: Value? {
        mutating get {
            guard let currentValue: Value = self.retrieved else {
                self.retrieved = storage.retrieve()
                return self.retrieved
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

// Thread-safe via NSRecursiveLock
public class RouterStore: @unchecked Sendable {
    public static let shared = RouterStore()

    private var routerOrder: [WeakRef<AnyObject>] = []
    private let lock = NSRecursiveLock()

    private init() {}
}

public extension RouterStore {
    func store<T: Routable>(router: T) {
        lock.lock()
        defer { lock.unlock() }

        // Clean up nil references
        routerOrder = routerOrder.filter { $0.value != nil }

        // Maintain order for LIFO retrieval (weak references only)
        let ref = WeakRef<AnyObject>(value: router)
        routerOrder.insert(ref, at: 0)
    }

    func retrieve<T: Routable>() -> T? {
        lock.lock()
        defer { lock.unlock() }

        // Search through ordered routers for type match (LIFO)
        for routerRef in routerOrder {
            if let router = routerRef.value as? T {
                return router
            }
        }

        return nil
    }
}
