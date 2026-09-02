import Foundation
import SwiftUI

protocol NavigationOutputable {
    func using(coordinator: Any, input: Any) -> ViewPresentable
}

protocol NavigationRootOutputable: NavigationOutputable {
    var routeTransition: AnyTransition { get }
}

public protocol RouteType {

}

public enum RootLayer {
    case front  // 새 뷰가 앞에 (높은 zIndex)
    case back   // 새 뷰가 뒤에 (낮은 zIndex, 이전 뷰가 위)
}

public struct RootSwitch: RouteType {
    var transition: AnyTransition
    var zOrder: RootLayer

    public init(_ transition: AnyTransition = .identity, zOrder: RootLayer = .front) {
        self.transition = transition
        self.zOrder = zOrder
    }
}

public struct Presentation: RouteType {
    let type: PresentationType
}

public struct Transition<T: NavigationCoordinatable, U: RouteType, Input, Output: ViewPresentable>: NavigationOutputable {
    let type: U
    let closure: ((T) -> ((Input) -> Output))

    func using(coordinator: Any, input: Any) -> ViewPresentable {
        if Input.self == Void.self {
            return closure(coordinator as! T)(() as! Input)
        } else {
            return closure(coordinator as! T)(input as! Input)
        }
    }
}

extension Transition: NavigationRootOutputable where U == RootSwitch {
    var routeTransition: AnyTransition { type.transition }
}

@propertyWrapper public class NavigationRoute<T: NavigationCoordinatable, U: RouteType, Input, Output: ViewPresentable> {

    public var wrappedValue: Transition<T, U, Input, Output>

    init(standard: Transition<T, U, Input, Output>) {
        self.wrappedValue = standard
    }
}

// MARK: - View overloads (PresentationType)

extension NavigationRoute where T: NavigationCoordinatable, Input == Void, Output == AnyView, U == Presentation {
    public convenience init<ViewOutput: View>(wrappedValue: @escaping ((T) -> (() -> ViewOutput)), _ presentation: PresentationType) {
        self.init(standard: Transition(type: Presentation(type: presentation), closure: { coordinator in
            return { _ in AnyView(wrappedValue(coordinator)()) }
        }))
    }
}

extension NavigationRoute where T: NavigationCoordinatable, Output == AnyView, U == Presentation {
    public convenience init<ViewOutput: View>(wrappedValue: @escaping ((T) -> ((Input) -> ViewOutput)), _ presentation: PresentationType) {
        self.init(standard: Transition(type: Presentation(type: presentation) , closure: { coordinator in
            return { input in AnyView(wrappedValue(coordinator)(input)) }
        }))
    }
}

// MARK: - Coordinator overloads (PresentationType, type-erased to AnyCoordinator)

extension NavigationRoute where T: NavigationCoordinatable, Input == Void, Output == AnyCoordinator, U == Presentation {
    public convenience init<CoordOutput: Coordinatable>(wrappedValue: @escaping ((T) -> (() -> CoordOutput)), _ presentation: PresentationType) {
        self.init(standard: Transition(type: Presentation(type: presentation), closure: { coordinator in
            return { _ in AnyCoordinator(wrappedValue(coordinator)()) }
        }))
    }
}

extension NavigationRoute where T: NavigationCoordinatable, Output == AnyCoordinator, U == Presentation {
    public convenience init<CoordOutput: Coordinatable>(wrappedValue: @escaping ((T) -> ((Input) -> CoordOutput)), _ presentation: PresentationType) {
        self.init(standard: Transition(type: Presentation(type: presentation), closure: { coordinator in
            return { input in AnyCoordinator(wrappedValue(coordinator)(input)) }
        }))
    }
}

// MARK: - View overloads (RootSwitch)

extension NavigationRoute where T: NavigationCoordinatable, Input == Void, Output == AnyView, U == RootSwitch {
    public convenience init<ViewOutput: View>(wrappedValue: @escaping ((T) -> (() -> ViewOutput))) {
        self.init(standard: Transition(type: RootSwitch(), closure: { coordinator in
            return { _ in AnyView(wrappedValue(coordinator)()) }
        }))
    }

    public convenience init<ViewOutput: View>(wrappedValue: @escaping ((T) -> (() -> ViewOutput)), _ transition: AnyTransition, zOrder: RootLayer = .front) {
        self.init(standard: Transition(type: RootSwitch(transition, zOrder: zOrder), closure: { coordinator in
            return { _ in AnyView(wrappedValue(coordinator)()) }
        }))
    }
}

extension NavigationRoute where T: NavigationCoordinatable, Output == AnyView, U == RootSwitch {
    public convenience init<ViewOutput: View>(wrappedValue: @escaping ((T) -> ((Input) -> ViewOutput))) {
        self.init(standard: Transition(type: RootSwitch(), closure: { coordinator in
            return { input in AnyView(wrappedValue(coordinator)(input)) }
        }))
    }

    public convenience init<ViewOutput: View>(wrappedValue: @escaping ((T) -> ((Input) -> ViewOutput)), _ transition: AnyTransition, zOrder: RootLayer = .front) {
        self.init(standard: Transition(type: RootSwitch(transition, zOrder: zOrder), closure: { coordinator in
            return { input in AnyView(wrappedValue(coordinator)(input)) }
        }))
    }
}

// MARK: - View controller overloads (RootSwitch)
//
// A root that is a plain `UIViewController`, for an app whose screens are UIKit. The
// output is a `Screen` rather than the view controller itself because a route's output
// has to be `ViewPresentable` — and conforming `UIViewController` to it retroactively
// would collide with every app and library that does the same.
//
// Only `@Root` for now. `@Route` would need the same treatment across twelve
// initialisers plus `focusFirst`'s input comparator, and the imperative
// `route(_:to viewController:)` already covers routing to a UIKit screen.

extension NavigationRoute where T: NavigationCoordinatable, Input == Void, Output == Screen, U == RootSwitch {
    public convenience init<VCOutput: UIViewController>(wrappedValue: @escaping ((T) -> (() -> VCOutput))) {
        self.init(standard: Transition(type: RootSwitch(), closure: { coordinator in
            return { _ in Screen.viewController(wrappedValue(coordinator)()) }
        }))
    }

    public convenience init<VCOutput: UIViewController>(wrappedValue: @escaping ((T) -> (() -> VCOutput)), _ transition: AnyTransition, zOrder: RootLayer = .front) {
        self.init(standard: Transition(type: RootSwitch(transition, zOrder: zOrder), closure: { coordinator in
            return { _ in Screen.viewController(wrappedValue(coordinator)()) }
        }))
    }
}

extension NavigationRoute where T: NavigationCoordinatable, Output == Screen, U == RootSwitch {
    public convenience init<VCOutput: UIViewController>(wrappedValue: @escaping ((T) -> ((Input) -> VCOutput))) {
        self.init(standard: Transition(type: RootSwitch(), closure: { coordinator in
            return { input in Screen.viewController(wrappedValue(coordinator)(input)) }
        }))
    }

    public convenience init<VCOutput: UIViewController>(wrappedValue: @escaping ((T) -> ((Input) -> VCOutput)), _ transition: AnyTransition, zOrder: RootLayer = .front) {
        self.init(standard: Transition(type: RootSwitch(transition, zOrder: zOrder), closure: { coordinator in
            return { input in Screen.viewController(wrappedValue(coordinator)(input)) }
        }))
    }
}

// MARK: - Coordinator overloads (RootSwitch, type-erased to AnyCoordinator)

extension NavigationRoute where T: NavigationCoordinatable, Input == Void, Output == AnyCoordinator, U == RootSwitch {
    public convenience init<CoordOutput: Coordinatable>(wrappedValue: @escaping ((T) -> (() -> CoordOutput))) {
        self.init(standard: Transition(type: RootSwitch(), closure: { coordinator in
            return { _ in AnyCoordinator(wrappedValue(coordinator)()) }
        }))
    }

    public convenience init<CoordOutput: Coordinatable>(wrappedValue: @escaping ((T) -> (() -> CoordOutput)), _ transition: AnyTransition, zOrder: RootLayer = .front) {
        self.init(standard: Transition(type: RootSwitch(transition, zOrder: zOrder), closure: { coordinator in
            return { _ in AnyCoordinator(wrappedValue(coordinator)()) }
        }))
    }
}

extension NavigationRoute where T: NavigationCoordinatable, Output == AnyCoordinator, U == RootSwitch {
    public convenience init<CoordOutput: Coordinatable>(wrappedValue: @escaping ((T) -> ((Input) -> CoordOutput))) {
        self.init(standard: Transition(type: RootSwitch(), closure: { coordinator in
            return { input in AnyCoordinator(wrappedValue(coordinator)(input)) }
        }))
    }

    public convenience init<CoordOutput: Coordinatable>(wrappedValue: @escaping ((T) -> ((Input) -> CoordOutput)), _ transition: AnyTransition, zOrder: RootLayer = .front) {
        self.init(standard: Transition(type: RootSwitch(transition, zOrder: zOrder), closure: { coordinator in
            return { input in AnyCoordinator(wrappedValue(coordinator)(input)) }
        }))
    }
}

// MARK: - AnyPresentationType overloads (enables .push(), .modal() dot syntax)

extension NavigationRoute where T: NavigationCoordinatable, Input == Void, Output == AnyView, U == Presentation {
    public convenience init<ViewOutput: View>(wrappedValue: @escaping ((T) -> (() -> ViewOutput)), _ presentation: AnyPresentationType) {
        self.init(standard: Transition(type: Presentation(type: presentation), closure: { coordinator in
            return { _ in AnyView(wrappedValue(coordinator)()) }
        }))
    }
}

extension NavigationRoute where T: NavigationCoordinatable, Output == AnyView, U == Presentation {
    public convenience init<ViewOutput: View>(wrappedValue: @escaping ((T) -> ((Input) -> ViewOutput)), _ presentation: AnyPresentationType) {
        self.init(standard: Transition(type: Presentation(type: presentation), closure: { coordinator in
            return { input in AnyView(wrappedValue(coordinator)(input)) }
        }))
    }
}

extension NavigationRoute where T: NavigationCoordinatable, Input == Void, Output == AnyCoordinator, U == Presentation {
    public convenience init<CoordOutput: Coordinatable>(wrappedValue: @escaping ((T) -> (() -> CoordOutput)), _ presentation: AnyPresentationType) {
        self.init(standard: Transition(type: Presentation(type: presentation), closure: { coordinator in
            return { _ in AnyCoordinator(wrappedValue(coordinator)()) }
        }))
    }
}

extension NavigationRoute where T: NavigationCoordinatable, Output == AnyCoordinator, U == Presentation {
    public convenience init<CoordOutput: Coordinatable>(wrappedValue: @escaping ((T) -> ((Input) -> CoordOutput)), _ presentation: AnyPresentationType) {
        self.init(standard: Transition(type: Presentation(type: presentation), closure: { coordinator in
            return { input in AnyCoordinator(wrappedValue(coordinator)(input)) }
        }))
    }
}
