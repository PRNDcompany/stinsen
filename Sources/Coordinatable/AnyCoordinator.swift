import Foundation
import SwiftUI

// MARK: - Abstract base class
//
// 타입 소거(type-erasure) 박스는 nonisolated init이 필요하다 (opaque `some Coordinatable`
// 반환을 nonisolated 컨텍스트에서도 만들 수 있어야 하므로). 클래스 자체는 nonisolated로 두고,
// Coordinatable의 MainActor 요구사항(view/parent/dismissChild)만 @MainActor로 명시한다.
fileprivate nonisolated class _AnyCoordinatorBase: Coordinatable {
    @MainActor func view() -> AnyView {
        fatalError("must override")
    }

    @MainActor var parent: ChildDismissable? {
        get { fatalError("must override") }
        set { fatalError("must override") }
    }

    @MainActor func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        fatalError("must override")
    }

    nonisolated var id: String {
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

    @MainActor override var parent: ChildDismissable? {
        get { base.parent }
        set { base.parent = newValue }
    }

    @MainActor override func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        base.dismissChild(coordinator: coordinator, action: action)
    }

    nonisolated override var id: String {
        _id
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

    @MainActor public func view() -> AnyView {
        box.view()
    }

    nonisolated public var id: String {
        _id
    }

    private nonisolated(unsafe) var box: _AnyCoordinatorBase
    private nonisolated(unsafe) var _id: String

    nonisolated public init<Base: Coordinatable>(_ base: Base) {
        box = _AnyCoordinatorBox(base)
        _id = base.id
    }
}
