import Foundation
import RobinHood
import CommonWallet
import IrohaCrypto

extension WalletNetworkFacade {
    func createHistoryMergeOperation(dependingOn transfersOperation: BaseOperation<SubscanTransferData>?,
                                     rewards: BaseOperation<SubscanRewardData>?,
                                     localOperation: BaseOperation<[TransactionHistoryItem]>?,
                                     asset: WalletAsset,
                                     address: String)
        -> BaseOperation<TransactionHistoryMergeResult> {
        let currentNetworkType = networkType
        let addressFactory = SS58AddressFactory()

        return ClosureOperation {
            let pageData = try transfersOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            if let localTransactions = try localOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled),
                !localTransactions.isEmpty {
                let manager = TransactionHistoryMergeManager(address: address,
                                                             networkType: currentNetworkType,
                                                             asset: asset,
                                                             addressFactory: addressFactory)
                return manager.merge(subscanItems: pageData?.transfers ?? [],
                                     localItems: localTransactions)
            } else {
                let transactions: [AssetTransactionData] = (pageData?.transfers ?? []).map { item in
                    AssetTransactionData.createTransaction(from: item,
                                                           address: address,
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
                                   transferOperation: BaseOperation<SubscanTransferData>?,
                                   rewardOperation: BaseOperation<SubscanRewardData>?,
                                   transferInfo: HistoryInfo,
                                   rewardInfo: RewardInfo) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let transferPageData = try transferOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let rewardPageData = try rewardOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let mergeResult = try mergeOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let isTransferComplete = (transferPageData?.transfers?.count ?? 0) < transferInfo.row
            let transferNextPage = transferPageData != nil ? transferInfo.page + 1 : transferInfo.page
            let isRewardComplete = (rewardPageData?.items?.count ?? 0) < transferInfo.row
            let rewardNextPage = rewardPageData != nil ? rewardInfo.page + 1 : rewardInfo.page

            let newHistoryContext = TransactionHistoryContext(transfersPage: transferNextPage,
                                                              isTransfersComplete: isTransferComplete,
                                                              rewardsPage: rewardNextPage,
                                                              isRewardsComplete: isRewardComplete)

            return AssetTransactionPageData(transactions: mergeResult.historyItems,
                                            context: newHistoryContext.toContext())
        }
    }
}
