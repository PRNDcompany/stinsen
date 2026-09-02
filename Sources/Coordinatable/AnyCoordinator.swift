import Foundation
import SwiftUI
import UIKit

// MARK: - Abstract base class
//
// 타입 소거(type-erasure) 박스는 nonisolated init이 필요하다 (opaque `some Coordinatable`
// 반환을 nonisolated 컨텍스트에서도 만들 수 있어야 하므로). 클래스 자체는 nonisolated로 두고,
// Coordinatable의 MainActor 요구사항(view/parent/dismissChild)만 @MainActor로 명시한다.
fileprivate nonisolated class _AnyCoordinatorBase: Coordinatable {
    @MainActor func view() -> AnyView {
        fatalError("must override")
    }

    @MainActor func viewController() -> UIViewController {
        fatalError("must override")
    }

    @MainActor var parent: ChildDismissable? {
        get { fatalError("must override") }
        set { fatalError("must override") }
    }

    @MainActor func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        fatalError("must override")
    }

    @MainActor func configure(_ viewController: UIViewController) {
        fatalError("must override")
    }

    nonisolated var id: String {
        fatalError("must override")
    }

    /// The wrapped instance, as an object. Needed because erasing hides the concrete
    /// type from `as?` — see `AnyCoordinator.unwrap(_:)`.
    nonisolated var baseObject: AnyObject {
        fatalError("must override")
    }

    nonisolated init() {
        guard type(of: self) != _AnyCoordinatorBase.self else {
            fatalError("_AnyCoordinatorBase instances can not be created; create a subclass instance instead")
        }
    }
}

// MARK: - Box container class
fileprivate nonisolated final class _AnyCoordinatorBox<Base: Coordinatable>: _AnyCoordinatorBase {
    // nonisolated(unsafe) allows nonisolated init to set these.
    // Safe: only mutated during init, then accessed on MainActor.
    nonisolated(unsafe) let base: Base
    private let _id: String

    nonisolated init(_ base: Base) {
        self.base = base
        self._id = base.id
    }

    @MainActor override func view() -> AnyView {
        self.base.view()
    }

    @MainActor override func viewController() -> UIViewController {
        self.base.viewController()
    }

    @MainActor override var parent: ChildDismissable? {
        get { base.parent }
        set { base.parent = newValue }
    }

    @MainActor override func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        base.dismissChild(coordinator: coordinator, action: action)
    }

    @MainActor override func configure(_ viewController: UIViewController) {
        base.configure(viewController)
    }

    nonisolated override var id: String {
        _id
    }

    nonisolated override var baseObject: AnyObject {
        base
    }
}

// MARK: - AnyCoordinator Wrapper
/// Type-erased wrapper for any `Coordinatable` type, analogous to `AnyView` for `View`.
/// Enables opaque return types (`some Coordinatable`) in route declarations.

public nonisolated final class AnyCoordinator: Coordinatable {
    @MainActor public var parent: ChildDismissable? {
        get { box.parent }
        set { box.parent = newValue }
    }

    @MainActor public func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        box.dismissChild(coordinator: coordinator, action: action)
    }

    /// Forwarded for the same reason `viewController()` is: the erased coordinator's own
    /// hook, not the box's no-op default. Nothing inside the library needs this — a boxed
    /// coordinator's `viewController()` calls its own `configure` — but a caller who reaches
    /// for it through the box should not be met with silence.
    @MainActor public func configure(_ viewController: UIViewController) {
        box.configure(viewController)
    }

    @MainActor public func view() -> AnyView {
        box.view()
    }

    /// Forwarded rather than inherited from the protocol default.
    ///
    /// The default hosts `view()` in a `UIHostingController`, which would wrap the
    /// erased coordinator's own view controller in a second one — and for a coordinator
    /// whose screens are UIKit, that wrapper is exactly what routing to it should avoid.
    @MainActor public func viewController() -> UIViewController {
        box.viewController()
    }

    nonisolated public var id: String {
        _id
    }

    /// The erased coordinator as a bare object.
    ///
    /// Erasure hides the concrete type from `as?` *and* replaces the object `===` would
    /// compare, so any identity question about a boxed coordinator has to go through
    /// here first. Use `unwrap(_:)` when the concrete type is what you want.
    nonisolated public var baseObject: AnyObject { box.baseObject }

    /// Recovers the concrete coordinator that was erased.
    ///
    /// Route declarations erase coordinator outputs to `AnyCoordinator` so that
    /// factories can return `some Coordinatable`. That means `route(to:)`, `root(_:)`
    /// and `hasRoot(_:)` hand back a box rather than your type — use this to get back
    /// to the coordinator's own API.
    ///
    ///     coordinator.hasRoot(\.authenticated)?.unwrap(AuthenticatedCoordinator.self)
    ///
    /// Returns `nil` if the erased coordinator is not of the requested type.
    nonisolated public func unwrap<T: Coordinatable>(_ type: T.Type = T.self) -> T? {
        if let direct = box.baseObject as? T { return direct }
        // Tolerate nesting, e.g. AnyCoordinator(AnyCoordinator(x)).
        return (box.baseObject as? AnyCoordinator)?.unwrap(type)
    }

    private nonisolated(unsafe) var box: _AnyCoordinatorBase
    private nonisolated(unsafe) var _id: String

    nonisolated public init<Base: Coordinatable>(_ base: Base) {
        box = _AnyCoordinatorBox(base)
        _id = base.id
    }
}
