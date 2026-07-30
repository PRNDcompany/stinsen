//
//  UIKitPresentationReentryTests.swift
//  StinsenTests
//
//  Unit tests for UIKitPresentation re-entry scenarios
//

import XCTest
@testable import Stinsen
#if canImport(UIKit)
import UIKit
import SwiftUI

@MainActor
final class UIKitPresentationReentryTests: XCTestCase {

    var coordinator: TestReentryCoordinator!
    var parentViewController: UIViewController!

    override func setUp() {
        super.setUp()
        coordinator = TestReentryCoordinator()
        parentViewController = UIViewController()
    }

    override func tearDown() {
        coordinator = nil
        parentViewController = nil
        super.tearDown()
    }

    // MARK: - Re-entry Tests

    func testPushPopPushScenario() {
        // Given
        let expectation = XCTestExpectation(description: "Re-entry works")

        // First push: A → B
        coordinator.route(to: \.detail)
        XCTAssertEqual(coordinator.stack.value.count, 1)

        // Pop: B → A
        coordinator.popLast()
        XCTAssertEqual(coordinator.stack.value.count, 0)

        // Second push (re-entry): A → B
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.coordinator.route(to: \.detail)
            XCTAssertEqual(self.coordinator.stack.value.count, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // NOTE: presented(parent:content:onAppeared:onDismissed:) 콜백 검증 테스트 2건은 삭제됨 —
    // 체크포인트(명단 감지기 재설계)에서 presented()의 생명주기 콜백 자체가 제거되었고,
    // "조기 통지 금지"는 이제 RemovalLedgerObserver(viewDidDisappear 판정)가 구조적으로 보장한다.

    func testMakeViewControllerCreatesCorrectType() {
        // Given
        let presentation = UIKitPresentation(
            make: { content, _ in UIHostingController(rootView: content) },
            present: { _, _ in }
        )

        // When
        let vc = presentation.makeViewController(content: Text("Test"))

        // Then
        XCTAssertTrue(vc is UIHostingController<AnyView>)
    }
}

// MARK: - Test Helpers

@MainActor
final class TestReentryCoordinator: NavigationCoordinatable {
    let stack = CoordinatorStack<TestReentryCoordinator>(initial: \.main)

    @Root var main = makeMain
    @Route(.push) var detail = makeDetail
    @Route(.modal) var modal = makeModal

    func makeMain() -> some View {
        Text("Main")
    }

    func makeDetail() -> some View {
        Text("Detail")
    }

    func makeModal() -> some View {
        Text("Modal")
    }
}

#endif
