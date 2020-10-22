import Foundation
import IrohaCrypto

extension NSPredicate {
    static func filterBy(networkType: SNAddressType) -> NSPredicate {
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
}
