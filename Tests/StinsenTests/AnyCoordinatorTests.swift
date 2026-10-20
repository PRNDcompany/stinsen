import XCTest
@testable import Stinsen
import SwiftUI

@MainActor
final class AnyCoordinatorTests: XCTestCase {

    // MARK: - Forwarding Tests

    func testViewForwardsToBase() {
        // Given
        let base = MockCoordinator()
        let anyCoordinator = AnyCoordinator(base)

        // When
        let view = anyCoordinator.view()

        // Then — should not crash, returns AnyView
        XCTAssertNotNil(view)
    }

    func testParentForwardsToBase() {
        // Given
        let base = MockCoordinator()
        let anyCoordinator = AnyCoordinator(base)
        let mockParent = MockParent()

        // When
        anyCoordinator.parent = mockParent

        // Then
        XCTAssertTrue(base.parent === mockParent)
        XCTAssertTrue(anyCoordinator.parent === mockParent)
    }

    func testDismissChildForwardsToBase() {
        // Given
        let base = MockCoordinator()
        let anyCoordinator = AnyCoordinator(base)
        let child = MockCoordinator()

        // When
        anyCoordinator.dismissChild(coordinator: child, action: nil)

        // Then
        XCTAssertTrue(base.dismissChildCalled)
    }

    // MARK: - Identity Tests

    func testIdMatchesBase() {
        // Given
        let base = MockCoordinator()

        // When
        let anyCoordinator = AnyCoordinator(base)

        // Then
        XCTAssertEqual(anyCoordinator.id, base.id)
    }

    func testNonisolatedIdAccess() {
        // Given
        let base = MockCoordinator()
        let anyCoordinator = AnyCoordinator(base)
        let expectedId = base.id

        // When — access id from nonisolated context
        let id = getNonisolatedId(anyCoordinator)

        // Then
        XCTAssertEqual(id, expectedId)
    }

    // MARK: - Helpers

    nonisolated func getNonisolatedId(_ coordinator: AnyCoordinator) -> String {
        coordinator.id
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockCoordinator: Coordinatable {
    var parent: ChildDismissable?
    var dismissChildCalled = false

    func view() -> AnyView {
        AnyView(Text("Mock"))
    }

    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {
        dismissChildCalled = true
    }
}

@MainActor
private final class MockParent: ChildDismissable {
    func dismissChild<T: Coordinatable>(coordinator: T, action: (() -> Void)?) {}
}
