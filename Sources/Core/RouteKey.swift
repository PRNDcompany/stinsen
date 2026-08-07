import Foundation

/// Identifies *which route* produced a screen.
///
/// This is the one piece of navigation identity UIKit cannot supply: UIKit knows the
/// order of view controllers and owns their lifetimes, but it has no idea that a
/// particular screen came from `\.reviewList` or from `route(.push, to:, id:)`.
///
/// Replaces the previous `keyPath: Int` (a `KeyPath.hashValue`), which was compared
/// with `==` for correctness. A hash collision there would silently send
/// `focusFirst(\.a)` to `\.b`, and the `Int.min`-based counter used for imperative
/// routes assumed keypath hashes are positive — which is not guaranteed.
/// ### Why this is not `Sendable`
///
/// `AnyKeyPath` is a class and does not conform to `Sendable` — declaring conformance
/// here is a warning today and an error under the Swift 6 language mode (verified with
/// `-strict-concurrency=complete`). `@unchecked Sendable` would silence that, but it
/// switches off the check rather than answering it.
///
/// Nothing needs it: `RouteKey` is produced, stored and read entirely inside
/// `@MainActor` isolation (`NavigationCoordinatable`, the route records, and the
/// lifecycle callbacks are all main-actor bound). If a future caller genuinely needs to
/// send one across isolation, that should surface as a real error and be answered then
/// — not pre-silenced now.
public struct RouteKey: Hashable {

    private enum Storage: Hashable {
        /// A declared `@Route` / `@Root`. Exact equality, no hashing involved.
        case declared(AnyKeyPath)
        /// An imperative route the caller named, so it can be navigated back to.
        case named(String)
        /// An imperative route with no name. Unique, and unreachable by lookup —
        /// which is correct: there is nothing to look it up *by*.
        case anonymous(UUID)
    }

    private let storage: Storage

    private init(_ storage: Storage) {
        self.storage = storage
    }

    public static func declared(_ keyPath: AnyKeyPath) -> RouteKey {
        RouteKey(.declared(keyPath))
    }

    public static func named(_ id: String) -> RouteKey {
        RouteKey(.named(id))
    }

    public static func anonymous() -> RouteKey {
        RouteKey(.anonymous(UUID()))
    }

    /// The caller-supplied name, if this route has one.
    /// Read by the "go back to that screen" lookup that `route(..., id:)` exists for.
    public var name: String? {
        if case .named(let id) = storage { return id }
        return nil
    }
}

extension RouteKey: CustomStringConvertible {
    public var description: String {
        switch storage {
        case .declared(let keyPath): return "declared(\(keyPath))"
        case .named(let id): return "named(\(id))"
        case .anonymous: return "anonymous"
        }
    }
}
