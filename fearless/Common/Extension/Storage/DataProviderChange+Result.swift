import Foundation
import RobinHood

extension DataProviderChange {
    var item: T? {
        switch self {
        case .insert(let newItem), .update(let newItem):
            return newItem
        case .delete:
            return nil
        }
    }

    static func change<P: Identifiable & Equatable> (value1: P?, value2: P?)
        -> DataProviderChange<P>? {
        guard let currentItem = value1 else {
            if let newItem = value2 {
                return DataProviderChange<P>.insert(newItem: newItem)
            } else {
                return nil
            }
        }

        guard let newItem = value2 else {
            return DataProviderChange<P>.delete(deletedIdentifier: currentItem.identifier)
        }

        if newItem != currentItem {
            return DataProviderChange<P>.update(newItem: newItem)
        } else {
            return nil
        }
    }
}
