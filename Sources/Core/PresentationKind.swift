import Foundation

/// How a screen was put on screen.
///
/// `.push`, `.modal` and `.fullScreen` are built by this library, so their view
/// controllers are ours and their teardown is predictable. `.custom` is whatever the
/// app supplied through `AnyPresentationType(make:present:dismiss:)` — it can do child
/// containment, an overlay, a separate window, or an asynchronous transition, none of
/// which is guaranteed to show up where we would look for it.
///
/// Two things need this distinction, and neither can be derived from the view
/// controller's position in the hierarchy:
///
/// 1. **Teardown routing.** A custom presentation must be torn down through the app's
///    own dismiss closure, or whatever it does there — a reverse hero animation, its
///    own cleanup — is skipped. And the topology cannot tell us that: a custom
///    presentation that pushed its view controller into a navigation controller looks
///    exactly like an ordinary `.push`, yet one may be batch-popped through UIKit and
///    the other may not. This is also what lets `popToRoot` collapse whole runs of
///    built-in screens in a single UIKit call while still stepping through custom ones
///    one at a time.
/// 2. **Diagnostics.** A `.push` with no `UINavigationController` in scope is a real
///    mistake, and today it is a silent no-op. An opaque closure gives us no way to
///    know it *intended* to push, so there is nothing to warn about without this.
///
/// Deliberately **not** a reason: liveness. An earlier draft claimed built-in kinds
/// need chain-membership checks while custom ones need an attachment check. They do
/// not — "is this view controller still attached to anything" is correct for every
/// kind, so liveness is uniform and needs no `kind`.
///
/// Existing `AnyPresentationType` initialisers default to `.custom`, so app code that
/// builds its own presentations keeps compiling and keeps working.
public enum PresentationKind: Hashable, Sendable {
    case push
    case modal
    case fullScreen
    case custom

}
