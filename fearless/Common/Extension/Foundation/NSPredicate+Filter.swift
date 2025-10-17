import Foundation
import IrohaCrypto
import SSFModels
import SSFAssetManagmentStorage

extension NSPredicate {
    // TODO: Remove
    static func filterAccountBy(networkType: SNAddressType) -> NSPredicate {
        let rawValue = Int16(networkType.rawValue)
        return NSPredicate(format: "%K == %d", #keyPath(SSFAssetManagmentStorage.CDMetaAccount.order), rawValue)
    }

    static func filterTransactionsBy(address: String) -> NSPredicate {
        let senderPredicate = filterTransactionsBySender(address: address)
        let receiverPredicate = filterTransactionsByReceiver(address: address)

        let orPredicates = [senderPredicate, receiverPredicate]
        return NSCompoundPredicate(orPredicateWithSubpredicates: orPredicates)
    }

    static func filterTransactionsBySender(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(SSFAssetManagmentStorage.CDTransactionHistoryItem.sender), address)
    }

    static func filterTransactionsByReceiver(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(SSFAssetManagmentStorage.CDTransactionHistoryItem.receiver), address)
    }

    static func filterContactsByTarget(address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(SSFAssetManagmentStorage.CDContactItem.targetAddress), address)
    }

    static func filterRuntimeMetadataItemsBy(identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(SSFAssetManagmentStorage.CDRuntimeMetadataItem.identifier), identifier)
    }

    static func filterStorageItemsBy(identifier: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(SSFAssetManagmentStorage.CDChainStorageItem.identifier), identifier)
    }

    static func filterByIdPrefix(_ prefix: String) -> NSPredicate {
        NSPredicate(format: "%K BEGINSWITH %@", #keyPath(SSFAssetManagmentStorage.CDChainStorageItem.identifier), prefix)
    }

    static func filterByStash(_ address: String) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(CDStashItem.stash), address)
    }

    static func filterByStashOrController(_ address: String) -> NSPredicate {
        let stash = filterByStash(address)
        let controller = NSPredicate(format: "%K == %@", #keyPath(CDStashItem.controller), address)

        return NSCompoundPredicate(orPredicateWithSubpredicates: [stash, controller])
    }

    static func filterAccountItemByAccountId(_ accountId: AccountId) -> NSPredicate {
        let hexAccountId = accountId.toHex()

        let substrateAccountFilter = NSPredicate(
            format: "%K == %@",
            #keyPath(SSFAssetManagmentStorage.CDMetaAccount.substrateAccountId), hexAccountId
        )

        let ethereumAccountFilter = NSPredicate(
            format: "%K == %@",
            #keyPath(SSFAssetManagmentStorage.CDMetaAccount.ethereumAddress), hexAccountId
        )

        let chainAccountFilter = NSPredicate(
            format: "ANY %K == %@", #keyPath(SSFAssetManagmentStorage.CDMetaAccount.chainAccounts.accountId), hexAccountId
        )

        return NSCompoundPredicate(orPredicateWithSubpredicates: [
            substrateAccountFilter,
            ethereumAccountFilter,
            chainAccountFilter
        ])
    }

    static func selectedMetaAccount() -> NSPredicate {
        NSPredicate(format: "%K == true", #keyPath(SSFAssetManagmentStorage.CDMetaAccount.isSelected))
    }

    static func relayChains() -> NSPredicate {
        NSPredicate(format: "%K = nil", #keyPath(SSFAssetManagmentStorage.CDChain.parentId))
    }

    static func chainBy(identifier: ChainModel.Id) -> NSPredicate {
        NSPredicate(format: "%K == %@", #keyPath(SSFAssetManagmentStorage.CDChain.chainId), identifier)
    }

    static func hasCrowloans() -> NSPredicate {
        NSPredicate(format: "%K == true", #keyPath(SSFAssetManagmentStorage.CDChain.hasCrowdloans))
    }

    static func enabledCHain() -> NSPredicate {
        NSPredicate(format: "%K == false", #keyPath(SSFAssetManagmentStorage.CDChain.disabled))
    }
}
