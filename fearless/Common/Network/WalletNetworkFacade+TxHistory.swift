import Foundation
import RobinHood
import CommonWallet
import IrohaCrypto

extension WalletNetworkFacade {
    func createHistoryMergeOperation(dependingOn subscanOperation: BaseOperation<SubscanHistoryData>,
                                     localOperation: BaseOperation<[TransactionHistoryItem]>?,
                                     asset: WalletAsset,
                                     info: HistoryInfo)
        -> BaseOperation<TransactionHistoryMergeResult> {
        let currentNetworkType = networkType
        let addressFactory = SS58AddressFactory()

        return ClosureOperation {
            let pageData = try subscanOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            if let localTransactions = try localOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled),
                !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(address: info.address,
                                                             networkType: currentNetworkType,
                                                             asset: asset,
                                                             addressFactory: addressFactory)
                return manager.merge(subscanItems: pageData.transactions ?? [],
                                     localItems: localTransactions)
            } else {
                let transactions: [AssetTransactionData] = (pageData.transactions ?? []).map { item in
                    AssetTransactionData.createTransaction(from: item,
                                                           address: info.address,
                                                           networkType: currentNetworkType,
                                                           asset: asset,
                                                           addressFactory: addressFactory)
                }

                return TransactionHistoryMergeResult(historyItems: transactions,
                                                     identifiersToRemove: [])
            }
        }
    }

    func createHistoryMapOperation(dependingOn mergeOperation: BaseOperation<TransactionHistoryMergeResult>,
                                   subscanOperation: BaseOperation<SubscanHistoryData>,
                                   info: HistoryInfo) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let pageData = try subscanOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let mergeResult = try mergeOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let isComplete = pageData.count < info.row
            let newHistoryContext = TransactionHistoryContext(page: info.page + 1,
                                                              isComplete: isComplete)

            return AssetTransactionPageData(transactions: mergeResult.historyItems,
                                            context: newHistoryContext.toContext())
        }
    }
}
