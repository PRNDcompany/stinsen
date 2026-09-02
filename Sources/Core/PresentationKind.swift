import Foundation

/// How a screen was put on screen.
///
/// `.push`, `.modal` and `.fullScreen` are built by this library, so their view
/// controllers are ours and their teardown is predictable. `.custom` is whatever the
/// app supplied through `AnyPresentationType(make:present:dismiss:)` — it can do child
/// containment, an overlay, a separate window, or an asynchronous transition, none of
/// which is guaranteed to show up where we would look for it.
///
/// ### This is a declaration, not a fact
///
/// The initialisers take `kind` as a parameter, so it says what the presentation's author
/// *meant*, and an app's presentation may declare `.push` while doing something else
/// entirely. That makes it fit for exactly one job:
///
/// **Diagnostics.** A `.push` with no `UINavigationController` in scope is a real mistake,
/// and left alone it is a silent no-op. An opaque closure gives no way to know a push was
/// even intended, so there is nothing to warn about without this — and a declaration is
/// good enough to warn on, because being wrong about it is itself worth hearing.
///
/// It is deliberately **not** used for:
///
/// - **Teardown routing.** Whether a screen may be batch-popped through UIKit or has to go
///   back out through the app's own `dismiss` closure is a question about who *built* the
///   presentation, and a declared kind answers a different question. Reading it here meant
///   an app presentation that called itself `.push` was collapsed into a
///   `popToViewController` with its own teardown skipped — the reverse animation and the
///   cleanup simply never ran. `AnyPresentationType.isBuiltIn` answers that instead, and
///   only this library can set it.
/// - **Liveness.** An earlier draft claimed built-in kinds need chain-membership checks
///   while custom ones need an attachment check. They do not — "is this view controller
///   still attached to anything" is correct for every kind.
///
/// Existing `AnyPresentationType` initialisers default to `.custom`, so app code that
/// builds its own presentations keeps compiling and keeps working.
public enum PresentationKind: Hashable, Sendable {
    case push
    case modal
    case fullScreen
    case custom

}
