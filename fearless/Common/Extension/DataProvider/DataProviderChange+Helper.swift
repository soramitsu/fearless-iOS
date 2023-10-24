import Foundation
import RobinHood

typealias DataProviderChangeFilter<S> = (S) -> Bool

extension Array {
    func reduceToLastChange<T>() -> T? where Element == DataProviderChange<T> {
        reduce(nil) { _, item in
            switch item {
            case let .insert(newItem), let .update(newItem):
                return newItem
            case .delete:
                return nil
            }
        }
    }

    func firstToLastChange<T>(filter: @escaping DataProviderChangeFilter<T>) -> T? where Element == DataProviderChange<T> {
        let change = first { item in
            switch item {
            case let .insert(newItem), let .update(newItem):
                return filter(newItem)
            case .delete:
                return false
            }
        }
        return change?.item
    }
}
