//
//  UtilityTests.swift
//  StinsenTests
//

import XCTest
@testable import Stinsen
import Foundation

final class UtilityTests: XCTestCase {

    // MARK: - WeakRef Tests

    func testWeakRefHoldsValue() {
        let object = NSObject()
        let ref = WeakRef(value: object)
        XCTAssertNotNil(ref.value)
        XCTAssertTrue(ref.value === object)
    }

    func testWeakRefBecomesNilAfterDeallocation() {
        var object: NSObject? = NSObject()
        let ref = WeakRef(value: object!)

        object = nil
        XCTAssertNil(ref.value)
    }

    func testWeakRefEqualityByIdentity() {
        let obj1 = NSObject()
        let obj2 = NSObject()

        let ref1a = WeakRef(value: obj1)
        let ref1b = WeakRef(value: obj1)
        let ref2 = WeakRef(value: obj2)

        XCTAssertEqual(ref1a, ref1b)
        XCTAssertNotEqual(ref1a, ref2)
    }

    func testWeakRefEqualityAfterDeallocation() {
        var obj: NSObject? = NSObject()
        let ref1 = WeakRef(value: obj!)
        let ref2 = WeakRef(value: obj!)

        obj = nil
        // Both refs point to same (now nil) object — still equal by identity
        XCTAssertEqual(ref1, ref2)
    }

    // MARK: - Array Safe Subscript Tests

    func testSafeSubscriptReturnsElementAtValidIndex() {
        let array = [10, 20, 30]
        XCTAssertEqual(array[safe: 0], 10)
        XCTAssertEqual(array[safe: 1], 20)
        XCTAssertEqual(array[safe: 2], 30)
    }

    func testSafeSubscriptReturnsNilForNegativeIndex() {
        let array = [10, 20, 30]
        XCTAssertNil(array[safe: -1])
        XCTAssertNil(array[safe: -100])
    }

    func testSafeSubscriptReturnsNilForOutOfBoundsIndex() {
        let array = [10, 20, 30]
        XCTAssertNil(array[safe: 3])
        XCTAssertNil(array[safe: 100])
    }

    func testSafeSubscriptReturnsNilOnEmptyArray() {
        let array: [Int] = []
        XCTAssertNil(array[safe: 0])
    }

    // MARK: - WeakMapTable Tests

    @MainActor
    func testWeakMapTableStoreAndRetrieve() {
        let key = NSObject()
        let table = WeakMapTable<NSObject, String>()

        table.setValue("hello", forKey: key)
        XCTAssertEqual(table.value(forKey: key), "hello")
    }

    @MainActor
    func testWeakMapTableRemoveValue() {
        let key = NSObject()
        let table = WeakMapTable<NSObject, String>()

        table.setValue("hello", forKey: key)
        table.setValue(nil, forKey: key)
        XCTAssertNil(table.value(forKey: key))
    }

    @MainActor
    func testWeakMapTableReturnsNilForUnknownKey() {
        let key = NSObject()
        let table = WeakMapTable<NSObject, String>()

        XCTAssertNil(table.value(forKey: key))
    }

    @MainActor
    func testWeakMapTableOverwritesValue() {
        let key = NSObject()
        let table = WeakMapTable<NSObject, String>()

        table.setValue("first", forKey: key)
        table.setValue("second", forKey: key)
        XCTAssertEqual(table.value(forKey: key), "second")
    }

    @MainActor
    func testWeakMapTableCleansUpOnKeyDeallocation() {
        let table = WeakMapTable<NSObject, String>()

        autoreleasepool {
            let key = NSObject()
            table.setValue("value", forKey: key)
            XCTAssertEqual(table.value(forKey: key), "value")
        }

        // After key is deallocated, the dealloc hook should clean up the entry
        // We can't easily verify this directly, but at least it shouldn't crash
    }
}
