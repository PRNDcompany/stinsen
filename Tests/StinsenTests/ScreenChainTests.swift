//
//  ScreenChainTests.swift
//  StinsenTests
//
//  `ScreenChain` is what later decisions read the hierarchy through — is this screen
//  still alive, where do we present from, what does unwinding have to close — so it
//  inherits whatever this gets wrong.
//
//  These run without a window: pushing into a `UINavigationController` and adding
//  children are synchronous and do not need one. Presentation does, and is covered by
//  the UI tests instead.
//

import XCTest
import UIKit
@testable import Stinsen

@MainActor
final class ScreenChainTests: XCTestCase {

    private func vc(_ label: String) -> UIViewController {
        let controller = UIViewController()
        controller.title = label
        return controller
    }

    /// A navigation controller with its root, view loaded.
    ///
    /// Loading the view is load-bearing: without it `UINavigationController` does not
    /// wire up containment, so `navigationController` stays nil on pushed children and
    /// every assertion here silently tests nothing.
    private func navigationStack() -> (nav: UINavigationController, root: UIViewController) {
        let root = vc("root")
        let nav = UINavigationController(rootViewController: root)
        _ = nav.view
        return (nav, root)
    }

    /// A screen that *holds* a navigation controller rather than sitting in one — what
    /// hosting a SwiftUI `NavigationView` produces.
    private func hostContaining(_ nav: UINavigationController, label: String) -> UIViewController {
        let host = vc(label)
        _ = host.view
        host.addChild(nav)
        host.view.addSubview(nav.view)
        nav.didMove(toParent: host)
        return host
    }

    // MARK: - Pushes

    func testWalk_withNothingAbove_isEmpty() {
        let (_, root) = navigationStack()

        XCTAssertTrue(ScreenChain.walk(from: root).isEmpty)
    }

    func testWalk_returnsPushedScreensInOrder() {
        let (nav, root) = navigationStack()
        let a = vc("a"), b = vc("b")
        nav.pushViewController(a, animated: false)
        nav.pushViewController(b, animated: false)

        XCTAssertEqual(ScreenChain.walk(from: root).map { $0.title }, ["a", "b"])
    }

    func testWalk_startingMidStack_onlyReturnsScreensAbove() {
        let (nav, _) = navigationStack()
        let a = vc("a"), b = vc("b")
        nav.pushViewController(a, animated: false)
        nav.pushViewController(b, animated: false)

        XCTAssertEqual(ScreenChain.walk(from: a).map { $0.title }, ["b"],
                       "walking from a must not report a itself or anything below it")
    }

    /// The view controller a coordinator holds is often nested inside the one the
    /// navigation controller actually knows about.
    func testWalk_fromNestedChild_resolvesItsStackEntry() {
        let (nav, _) = navigationStack()
        let a = vc("a")
        nav.pushViewController(a, animated: false)

        let nested = vc("nested")
        a.addChild(nested)
        a.view.addSubview(nested.view)
        nested.didMove(toParent: a)

        XCTAssertEqual(nested.navigationStackEntry, a,
                       "a nested child's stack entry is the ancestor the nav controller holds")
        XCTAssertTrue(ScreenChain.walk(from: nested).isEmpty,
                      "nothing is pushed above a, so nothing is above the child either")
    }

    func testWalk_neverIncludesTheContainerItself() {
        let (nav, root) = navigationStack()
        nav.pushViewController(vc("a"), animated: false)

        let walked = ScreenChain.walk(from: root)
        XCTAssertFalse(walked.contains { $0 is UINavigationController },
                       "containers hold screens, they are not screens")
    }

    func testWalk_hasNoDuplicates() {
        let (nav, root) = navigationStack()
        nav.pushViewController(vc("a"), animated: false)
        nav.pushViewController(vc("b"), animated: false)

        let walked = ScreenChain.walk(from: root)
        let unique = Set(walked.map(ObjectIdentifier.init))
        XCTAssertEqual(walked.count, unique.count,
                       "duplicates would make record matching consume the wrong entry")
    }

    // MARK: - Attachment

    func testIsAttached_freshViewControllerIsNotAttached() {
        XCTAssertFalse(vc("loose").isAttachedToHierarchy)
    }

    func testIsAttached_pushedViewControllerIsAttached() {
        let (nav, _) = navigationStack()
        let a = vc("a")
        nav.pushViewController(a, animated: false)

        XCTAssertTrue(a.isAttachedToHierarchy)
    }

    func testIsAttached_poppedViewControllerIsNotAttached() {
        let (nav, _) = navigationStack()
        let a = vc("a")
        nav.pushViewController(a, animated: false)
        nav.popViewController(animated: false)

        XCTAssertFalse(a.isAttachedToHierarchy,
                       "a popped screen is gone, and liveness must say so")
    }

    func testIsAttached_childViewControllerIsAttached() {
        let host = vc("host")
        let child = vc("child")
        host.addChild(child)
        host.view.addSubview(child.view)
        child.didMove(toParent: host)

        XCTAssertTrue(child.isAttachedToHierarchy,
                      "custom presentations may attach by containment rather than pushing")
    }

    /// Liveness must not have side effects — it is read from places that must not
    /// mutate anything, including SwiftUI view bodies.
    func testIsAttached_doesNotLoadTheView() {
        let controller = vc("lazy")
        XCTAssertNil(controller.viewIfLoaded, "precondition: view not loaded yet")

        _ = controller.isAttachedToHierarchy

        XCTAssertNil(controller.viewIfLoaded,
                     "checking liveness must not load the view and run viewDidLoad")
    }

    // MARK: - Navigation controllers held inside a screen

    /// Presenting a coordinator wrapped in a `NavigationView` and then pushing.
    ///
    /// From UIKit's side the presented thing is a hosting controller with the
    /// `UINavigationController` as its *child*, so `navigationController` is nil on it
    /// and everything inside is invisible from above. A chain that stopped there would
    /// hand the next push a context with no navigation controller, and UIKit would do
    /// nothing at all — silently.
    func testWalk_descendsIntoANavigationControllerHeldByAScreen() {
        let (outerNav, root) = navigationStack()
        let (innerNav, innerRoot) = navigationStack()
        innerRoot.title = "modal-root"
        let host = hostContaining(innerNav, label: "modal")
        outerNav.pushViewController(host, animated: false)

        XCTAssertEqual(ScreenChain.walk(from: root).map { $0.title },
                       ["modal", "modal-root"],
                       "the screens inside the held navigation controller must be reachable")
    }

    func testWalk_includesScreensPushedInsideAHeldNavigationController() {
        let (outerNav, root) = navigationStack()
        let (innerNav, innerRoot) = navigationStack()
        innerRoot.title = "modal-root"
        let host = hostContaining(innerNav, label: "modal")
        outerNav.pushViewController(host, animated: false)
        let deep = vc("deep")
        innerNav.pushViewController(deep, animated: false)

        XCTAssertEqual(ScreenChain.walk(from: root).map { $0.title },
                       ["modal", "modal-root", "deep"])
    }

    /// A screen that sits in a navigation controller is not also searched for one it
    /// holds — otherwise a coordinator inside a `NavigationView` would rediscover its
    /// own navigation controller and report its siblings twice.
    func testWalk_prefersTheNavigationControllerAScreenSitsIn() {
        let (nav, root) = navigationStack()
        let a = vc("a")
        nav.pushViewController(a, animated: false)

        XCTAssertEqual(ScreenChain.walk(from: root).map { $0.title }, ["a"])
    }
}
