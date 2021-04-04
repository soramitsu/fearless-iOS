import Foundation
import RobinHood

struct WalletRemoteHistoryData {
    let historyItems: [WalletRemoteHistoryItemProtocol]
    let context: TransactionHistoryContext
}

protocol WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(for context: TransactionHistoryContext, address: String, count: Int)
        -> CompoundOperationWrapper<WalletRemoteHistoryData>
}

final class WalletRemoteHistoryFactory {
    let internalFactory = SubscanOperationFactory()

    let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    private func createTransfersOperationIfNeeded(
        for context: TransactionHistoryContext,
        address: String
    ) -> BaseOperation<SubscanTransferData>? {
        guard !context.transfers.isComplete else {
            return nil
        }

        let transfersURL = baseURL.appendingPathComponent(SubscanApi.transfers)
        let transferInfo = HistoryInfo(
            address: address,
            row: context.transfers.row,
            page: context.transfers.page
        )
        return internalFactory.fetchTransfersOperation(transfersURL, info: transferInfo)
    }

    private func createRewardsOperationIfNeeded(
        for context: TransactionHistoryContext,
        address: String
    ) -> BaseOperation<SubscanRewardData>? {
        guard !context.rewards.isComplete else {
            return nil
        }

        let rewardsURL = baseURL.appendingPathComponent(SubscanApi.rewardsAndSlashes)
        let rewardInfo = HistoryInfo(
            address: address,
            row: context.rewards.row,
            page: context.rewards.page
        )
        return internalFactory.fetchRewardsAndSlashesOperation(rewardsURL, info: rewardInfo)
    }

    private func createExtrinsicsOperationIfNeeded(
        for context: TransactionHistoryContext,
        address: String
    ) -> BaseOperation<SubscanExtrinsicData>? {
        guard !context.extrinsics.isComplete else {
            return nil
        }

        let extrinsicsURL = baseURL.appendingPathComponent(SubscanApi.extrinsics)
        let info = HistoryInfo(
            address: address,
            row: context.extrinsics.row,
            page: context.extrinsics.page
        )
        return internalFactory.fetchExtrinsicsOperation(extrinsicsURL, info: info)
    }

    private func createMapOperation(
        dependingOn transfersOperation: BaseOperation<SubscanTransferData>?,
        rewardsOperation: BaseOperation<SubscanRewardData>?,
        extrinsicsOperation: BaseOperation<SubscanExtrinsicData>?,
        context: TransactionHistoryContext,
        expectedCount _: Int
    ) -> BaseOperation<WalletRemoteHistoryData> {
        ClosureOperation {
            let transferPageData = try transfersOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let rewardPageData = try rewardsOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let extrinsicPageData = try extrinsicsOperation?
                .extractNoCancellableResultData()

            let transfers = transferPageData?.transfers ?? []
            let rewards = rewardPageData?.items ?? []
            let extrinsics = extrinsicPageData?.extrinsics ?? []

            let isCompletedMapping: [WalletRemoteHistorySourceLabel: Bool] =
                [
                    .transfers: transfers.count < context.transfers.row,
                    .rewards: rewards.count < context.rewards.row,
                    .extrinsics: extrinsics.count < context.extrinsics.row
                ]

            let resultItems: [WalletRemoteHistoryItemProtocol] =
                (transfers + rewards + extrinsics).sorted { item1, item2 in
                    if item1.itemBlockNumber > item2.itemBlockNumber {
                        return true
                    } else if item1.itemBlockNumber < item2.itemBlockNumber {
                        return false
                    }

                    return item1.itemExtrinsicIndex >= item2.itemExtrinsicIndex
                }

            let transfersIndex = resultItems.lastIndex { $0.label == .transfers }
            let rewardsIndex = resultItems.lastIndex { $0.label == .rewards }
            let extrinsicsIndex = resultItems.lastIndex { $0.label == .extrinsics }

            let truncationLength =
                (
                    (transfersIndex.map { [(WalletRemoteHistorySourceLabel.transfers, $0)] } ?? []) +
                        (rewardsIndex.map { [(WalletRemoteHistorySourceLabel.rewards, $0)] } ?? []) +
                        (extrinsicsIndex.map { [(WalletRemoteHistorySourceLabel.extrinsics, $0)] } ?? [])
                )
                .sorted { $0.1 < $1.1 }
                .first { !(isCompletedMapping[$0.0] ?? false) }
                .map { $0.1 + 1 }

            let truncatedItems: [WalletRemoteHistoryItemProtocol] = {
                if let length = truncationLength {
                    return Array(resultItems.prefix(length))
                } else {
                    return resultItems
                }
            }()

            return WalletRemoteHistoryData(
                historyItems: resultItems,
                context: context
            )
        }
    }
}

extension WalletRemoteHistoryFactory: WalletRemoteHistoryFactoryProtocol {
    func createOperationWrapper(for context: TransactionHistoryContext, address: String, count: Int)
        -> CompoundOperationWrapper<WalletRemoteHistoryData> {
        guard !context.isComplete else {
            let result = WalletRemoteHistoryData(historyItems: [], context: context)
            return CompoundOperationWrapper.createWithResult(result)
        }

        let transfersOperation = createTransfersOperationIfNeeded(for: context, address: address)
        let rewardsOperation = createRewardsOperationIfNeeded(for: context, address: address)
        let extrinsicsOperation = createExtrinsicsOperationIfNeeded(for: context, address: address)

        let dependencies = (transfersOperation.map { [$0] } ?? []) + (rewardsOperation.map { [$0] } ?? [])

        let mapOperation = createMapOperation(
            dependingOn: transfersOperation,
            rewardsOperation: rewardsOperation,
            extrinsicsOperation: extrinsicsOperation,
            context: context,
            expectedCount: count
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
