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
        address: String, count: Int
    ) -> BaseOperation<SubscanTransferData>? {
        guard !context.isTransfersComplete else {
            return nil
        }

        let transfersURL = baseURL.appendingPathComponent(SubscanApi.transfers)
        let transferInfo = HistoryInfo(address: address, row: count, page: context.transfersPage)
        return internalFactory.fetchTransfersOperation(transfersURL, info: transferInfo)
    }

    private func createRewardsOperationIfNeeded(
        for context: TransactionHistoryContext,
        address: String, count: Int
    ) -> BaseOperation<SubscanRewardData>? {
        guard !context.isRewardsComplete else {
            return nil
        }

        let rewardsURL = baseURL.appendingPathComponent(SubscanApi.rewards)
        let rewardInfo = RewardInfo(address: address, row: count, page: context.rewardsPage)
        return internalFactory.fetchRewardsAndSlashesOperation(rewardsURL, info: rewardInfo)
    }

    private func createMapOperation(
        dependingOn transfersOperation: BaseOperation<SubscanTransferData>?,
        rewardsOperation: BaseOperation<SubscanRewardData>?,
        context: TransactionHistoryContext,
        expecteCount: Int
    ) -> BaseOperation<WalletRemoteHistoryData> {
        ClosureOperation {
            let transferPageData = try transfersOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let rewardPageData = try rewardsOperation?
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let transfers = transferPageData?.transfers ?? []
            let rewards = rewardPageData?.items ?? []

            let isTransferComplete = transfers.count < expecteCount
            let transferNextPage = transferPageData != nil ? context.transfersPage + 1 : context.transfersPage
            let isRewardComplete = rewards.count < expecteCount
            let rewardNextPage = rewardPageData != nil ? context.rewardsPage + 1 : context.rewardsPage

            let newHistoryContext = TransactionHistoryContext(
                transfersPage: transferNextPage,
                isTransfersComplete: isTransferComplete,
                rewardsPage: rewardNextPage,
                isRewardsComplete: isRewardComplete
            )

            let resultItems: [WalletRemoteHistoryItemProtocol] = transfers + rewards

            return WalletRemoteHistoryData(
                historyItems: resultItems,
                context: newHistoryContext
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

        let transfersOperation = createTransfersOperationIfNeeded(for: context, address: address, count: count)
        let rewardsOperation = createRewardsOperationIfNeeded(for: context, address: address, count: count)

        let dependencies = (transfersOperation.map { [$0] } ?? []) + (rewardsOperation.map { [$0] } ?? [])

        let mapOperation = createMapOperation(
            dependingOn: transfersOperation,
            rewardsOperation: rewardsOperation,
            context: context,
            expecteCount: count
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
