import Foundation
import CommonWallet
import IrohaCrypto

struct TransactionHistoryMergeResult {
    let historyItems: [AssetTransactionData]
    let identifiersToRemove: [String]
}

enum TransactionHistoryMergeItem {
    case local(item: TransactionHistoryItem)
    case remote(remote: SubscanHistoryItemData)

    func compareWithItem(_ item: TransactionHistoryMergeItem) -> Bool {
        switch (self, item) {
        case (.local(let localItem1), .local(let localItem2)):
            if localItem1.status == .pending, localItem2.status != .pending {
                return true
            } else {
                return compareBlockNumberIfExists(number1: localItem1.blockNumber,
                                                  number2: localItem2.blockNumber,
                                                  timestamp1: localItem1.timestamp,
                                                  timestamp2: localItem2.timestamp)
            }

        case (.local(let localItem), .remote(let remoteItem)):
            if localItem.status == .pending {
                return true
            } else {
                return compareBlockNumberIfExists(number1: localItem.blockNumber,
                                                  number2: remoteItem.blockNumber,
                                                  timestamp1: localItem.timestamp,
                                                  timestamp2: remoteItem.timestamp)
            }
        case (.remote(let remoteItem), .local(let localItem)):
            if localItem.status == .pending {
                return false
            } else {
                return compareBlockNumberIfExists(number1: remoteItem.blockNumber,
                                                  number2: localItem.blockNumber,
                                                  timestamp1: remoteItem.timestamp,
                                                  timestamp2: localItem.timestamp)
            }
        case (.remote(let remoteItem1), .remote(let remoteItem2)):
            return compareBlockNumberIfExists(number1: remoteItem1.blockNumber,
                                              number2: remoteItem2.blockNumber,
                                              timestamp1: remoteItem1.timestamp,
                                              timestamp2: remoteItem2.timestamp)
        }
    }

    func buildTransactionData(address: String,
                              networkType: SNAddressType,
                              asset: WalletAsset,
                              addressFactory: SS58AddressFactoryProtocol) -> AssetTransactionData {
        switch self {
        case .local(let item):
            return AssetTransactionData.createTransaction(from: item,
                                                          address: address,
                                                          networkType: networkType,
                                                          asset: asset,
                                                          addressFactory: addressFactory)
        case .remote(let item):
            return AssetTransactionData.createTransaction(from: item,
                                                          address: address,
                                                          networkType: networkType,
                                                          asset: asset,
                                                          addressFactory: addressFactory)
        }
    }

    private func compareBlockNumberIfExists(number1: Int64?,
                                            number2: Int64?,
                                            timestamp1: Int64,
                                            timestamp2: Int64) -> Bool {
        if let number1 = number1, let number2 = number2 {
            return number1 != number2 ? number1 > number2 : timestamp1 > timestamp2
        }

        return timestamp1 > timestamp2
    }
}

final class TransactionHistoryMergeManager {

    let address: String
    let networkType: SNAddressType
    let asset: WalletAsset
    let addressFactory: SS58AddressFactoryProtocol

    init(address: String,
         networkType: SNAddressType,
         asset: WalletAsset,
         addressFactory: SS58AddressFactoryProtocol) {
        self.address = address
        self.networkType = networkType
        self.asset = asset
        self.addressFactory = addressFactory
    }

    func merge(subscanItems: [SubscanHistoryItemData],
               localItems: [TransactionHistoryItem]) -> TransactionHistoryMergeResult {
        let existingHashes = Set(subscanItems.map { $0.hash })
        let minSubscanItem = subscanItems.last

        let hashesToRemove: [String] = localItems.compactMap { item in
            if existingHashes.contains(item.txHash) {
                return item.txHash
            }

            guard let subscanItem = minSubscanItem else {
                return nil
            }

            if item.timestamp < subscanItem.timestamp {
                return item.txHash
            }

            return nil
        }

        let filterSet = Set(hashesToRemove)
        let localMergeItems: [TransactionHistoryMergeItem] = localItems.compactMap { item in
            guard !filterSet.contains(item.txHash) else {
                return nil
            }

            return TransactionHistoryMergeItem.local(item: item)
        }

        let remoteMergeItems: [TransactionHistoryMergeItem] = subscanItems.map {
            TransactionHistoryMergeItem.remote(remote: $0)
        }

        let transactionsItems = (localMergeItems + remoteMergeItems)
            .sorted { $0.compareWithItem($1) }
            .map { item in
                item.buildTransactionData(address: address,
                                          networkType: networkType,
                                          asset: asset,
                                          addressFactory: addressFactory)
        }

        let results = TransactionHistoryMergeResult(historyItems: transactionsItems,
                                                    identifiersToRemove: hashesToRemove)

        return results
    }
}
