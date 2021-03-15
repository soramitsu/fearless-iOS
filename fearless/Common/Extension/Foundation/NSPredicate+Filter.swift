import Foundation
import IrohaCrypto

extension NSPredicate {
    static func filterAccountBy(networkType: SNAddressType) -> NSPredicate {
        let rawValue = Int16(networkType.rawValue)
        return NSPredicate(format: "%K == %d", #keyPath(CDAccountItem.networkType), rawValue)
    }

    static func filterTransactionsBy(address: String) -> NSPredicate {
        let senderPredicate = filterTransactionsBySender(address: address)
        let receiverPredicate = filterTransactionsByReceiver(address: address)

        let orPredicates = [senderPredicate, receiverPredicate]
        return NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
    }

    static func filterTransactionsBySender(address: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(CDTransactionHistoryItem.sender), address)
    }

    static func filterTransactionsByReceiver(address: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(CDTransactionHistoryItem.receiver), address)
    }

    static func filterContactsByTarget(address: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(CDContactItem.targetAddress), address)
    }

    static func filterRuntimeMetadataItemsBy(identifier: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(CDRuntimeMetadataItem.identifier), identifier)
    }

    static func filterStorageItemsBy(identifier: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(CDChainStorageItem.identifier), identifier)
    }

    static func filterByIdPrefix(_ prefix: String) -> NSPredicate {
        return NSPredicate(format: "%K BEGINSWITH %@", #keyPath(CDChainStorageItem.identifier), prefix)
    }

    static func filterByStash(_ address: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(CDStashItem.stash), address)
    }

    static func filterByStashOrController(_ address: String) -> NSPredicate {
        let stash = filterByStash(address)
        let controller = NSPredicate(format: "%K == %@", #keyPath(CDStashItem.controller), address)

        return NSCompoundPredicate(orPredicateWithSubpredicates: [stash, controller])
    }
}
