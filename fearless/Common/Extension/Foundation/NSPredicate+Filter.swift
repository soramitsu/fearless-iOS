import Foundation
import IrohaCrypto
import SSFModels

extension NSPredicate {
    static func filterTransactionsBy(address: String) -> NSPredicate {
        let senderPredicate = filterTransactionsBySender(address: address)
        let receiverPredicate = filterTransactionsByReceiver(address: address)

        let orPredicates = [senderPredicate, receiverPredicate]
        return NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
    }

    static func filterTransactionsBySender(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", "sender", address)
    }

    static func filterTransactionsByReceiver(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", "receiver", address)
    }

    static func filterContactsByTarget(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", "targetAddress", address)
    }

    static func filterRuntimeMetadataItemsBy(identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", "identifier", identifier)
    }

    static func filterStorageItemsBy(identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", "identifier", identifier)
    }

    static func filterByIdPrefix(_ prefix: String) -> NSPredicate {
        NSPredicate(format: "%K BEGINSWITH %@", "identifier", prefix)
    }

    static func filterByStash(_ address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", "stash", address)
    }

    static func filterByStashOrController(_ address: String) -> NSPredicate {
        let stash = filterByStash(address)
        let controller = NSPredicate(format: "%K == %@", "controller", address)

        return NSCompoundPredicate(orPredicateWithSubpredicates: [stash, controller])
    }

    static func filterAccountItemByAccountId(_ accountId: AccountId) -> NSPredicate {
        let hexAccountId = accountId.toHex()

        let substrateAccountFilter = NSPredicate(
            format: "%K == %@",
            "substrateAccountId", hexAccountId
        )

        let ethereumAccountFilter = NSPredicate(
            format: "%K == %@",
            "ethereumAddress", hexAccountId
        )

        let chainAccountFilter = NSPredicate(
            format: "ANY %K == %@", "chainAccounts.accountId", hexAccountId
        )

        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            substrateAccountFilter,
            ethereumAccountFilter,
            chainAccountFilter
        ])
    }

    static func selectedMetaAccount() -> NSPredicate {
        NSPredicate(format: "%K == true", "isSelected")
    }

    static func relayChains() -> NSPredicate {
        NSPredicate(format: "%K = nil", "parentId")
    }

    static func chainBy(identifier: ChainModel.Id) -> NSPredicate {
        NSPredicate(format: "%K == %@", "chainId", identifier)
    }

    static func hasCrowloans() -> NSPredicate {
        NSPredicate(format: "%K == true", "hasCrowdloans")
    }

    static func enabledCHain() -> NSPredicate {
        NSPredicate(format: "%K == false", "disabled")
    }
}
