import SwiftUI
import UIKit

/// Everything a coordinator retains about one screen it opened.
///
/// Deliberately *not* a stack slot. The previous `NavigationStackItem` was addressed by
/// its position in an array, and that position travelled across call boundaries — into
/// view initialisers, dictionary keys and closure captures — where it could go stale
/// while remaining perfectly valid. A record is addressed by identity instead, and the
/// order is read back from UIKit.
///
/// The view controller is `weak` on purpose: UIKit owns the lifetime of what is on
/// screen, and a strong reference here would mean a screen the user closed is kept alive
/// by the coordinator's bookkeeping. It is also never used as a dictionary key —
/// `ObjectIdentifier` of a dead object can be reused by a later allocation — so lookups
/// are `===` over the array. Depth is single digits; this is cheaper than the hashing
/// would be.
@MainActor
struct RouteRecord {

    /// Where a screen is in its own presentation, which is not the same question as
    /// whether it is alive.
    ///
    /// `liveRecords()` derives liveness from UIKit, and a screen that has been asked for
    /// but not yet put on screen is attached to nothing — so without this, reconciling
    /// would delete records mid-presentation. `.pending` and `.presenting` are therefore
    /// held to be alive by definition; only `.live` records are subject to UIKit's
    /// verdict.
    enum State {
        /// Recorded, not handed to UIKit yet — no presentation context available.
        case pending
        /// Handed to a presentation whose attachment we cannot yet observe (custom).
        case presenting
        /// On screen, and from here on UIKit is the authority.
        case live
    }

    /// Identity for diffing across a reconcile. The view controller cannot serve: it is
    /// weak, so a record whose screen has been released would become indistinguishable
    /// from every other such record.
    let id = UUID()

    let route: RouteKey

    /// Legacy identity — `KeyPath.hashValue`, or a synthetic value for imperative
    /// routes. Retained solely to answer the deprecated `Int`-based public API
    /// (`currentRoute`, `isInStack(_:)`); nothing internal compares it any more.
    let keyPath: Int

    /// The value the route was created with, as `focusFirst`'s comparator will see it.
    let input: Any?

    let content: StackItemContent
    let presentation: AnyPresentationType

    /// Runs when this screen goes away, exactly once, whichever path removed it.
    var onDismiss: (() -> Void)?

    weak var viewController: UIViewController?

    var state: State = .pending

    /// The child coordinator this screen shows, already unwrapped from any erasure box.
    ///
    /// Stored rather than derived because the unwrapping has to happen exactly once and
    /// be impossible to forget: a `@Route` coordinator output is wrapped in
    /// `AnyCoordinator`, so comparing the box against the coordinator that later calls
    /// `dismissCoordinator()` silently never matches.
    let childObject: AnyObject?

    var child: (any Coordinatable)? {
        guard case .coordinator(let coordinator) = content else { return nil }
        return coordinator
    }

    var kind: PresentationKind { presentation.kind }

    init(
        route: RouteKey,
        keyPath: Int,
        input: Any?,
        content: StackItemContent,
        presentation: AnyPresentationType,
        onDismiss: (() -> Void)? = nil
    ) {
        self.route = route
        self.keyPath = keyPath
        self.input = input
        self.content = content
        self.presentation = presentation
        self.onDismiss = onDismiss
        if case .coordinator(let coordinator) = content {
            self.childObject = coordinatorInstance(coordinator)
        } else {
            self.childObject = nil
        }
    }
}

// MARK: - Erasure

/// The object behind a coordinator, with any `AnyCoordinator` boxes removed.
///
/// Declared routes erase their coordinator output so factories can return
/// `some Coordinatable`, but the object that later calls `dismissCoordinator()` is the
/// coordinator itself, not the box. Comparing the two with `===` — or casting the box
/// with `as?` — fails silently, which is exactly why `dismissChild` was reduced to
/// comparing `String` ids. Unwrap first and identity works again.
@MainActor
func coordinatorInstance<C: Coordinatable>(_ coordinator: C) -> AnyObject {
    coordinatorInstance(object: coordinator)
}

@MainActor
func coordinatorInstance(object: AnyObject) -> AnyObject {
    var current = object
    while let box = current as? AnyCoordinator {
        current = box.baseObject
    }
    return current
}
