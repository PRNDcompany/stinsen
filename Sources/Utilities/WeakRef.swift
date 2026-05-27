import Foundation

// see https://swiftrocks.com/weak-dictionary-values-in-swift
nonisolated final class WeakRef<T: AnyObject>: Equatable {
    static func == (lhs: WeakRef<T>, rhs: WeakRef<T>) -> Bool {
        lhs.value === rhs.value
    }

    weak var value: T?
    
    init(value: T) {
        self.value = value
    }

}
