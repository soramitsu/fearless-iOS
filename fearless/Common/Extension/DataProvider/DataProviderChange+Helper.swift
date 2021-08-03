import Foundation
import RobinHood

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
}
