import Foundation
import RobinHood

import SSFModels

protocol HistoryDataProviderFactoryProtocol {
    func createDataProvider(
        for address: String,
        asset: AssetModel,
        chain: ChainModel,
        targetIdentifier: String,
        filters: [WalletTransactionHistoryFilter]
    ) throws
        -> SingleValueProvider<AssetTransactionPageData>
}

class HistoryDataProviderFactory: BaseDataProviderFactory, HistoryDataProviderFactoryProtocol {
    let historySyncQueue = DispatchQueue(label: "co.jp.soramitsu.wallet.cache.history.queue")
    let executionQueue = OperationQueue()
    let operationFactory: HistoryOperationFactoryProtocol

    init(operationFactory: HistoryOperationFactoryProtocol) {
        self.operationFactory = operationFactory

        super.init()
    }

    enum Constants {
        static let historyDefaultPageSize = 100
    }

    func createDataProvider(
        for address: String,
        asset: AssetModel,
        chain: ChainModel,
        targetIdentifier: String,
        filters: [WalletTransactionHistoryFilter]
    ) throws
        -> SingleValueProvider<AssetTransactionPageData> {
        let pagination = Pagination(count: Constants.historyDefaultPageSize)

        let source: AnySingleValueProviderSource<AssetTransactionPageData> =
            AnySingleValueProviderSource {
                let operation = self.operationFactory
                    .fetchTransactionHistoryOperation(
                        asset: asset,
                        chain: chain,
                        address: address,
                        filters: filters,
                        pagination: pagination
                    )
                return operation
            }

        let cache = createSingleValueCache()

        let updateTrigger = DataProviderEventTrigger.onAddObserver

        return SingleValueProvider(
            targetIdentifier: targetIdentifier,
            source: source,
            repository: AnyDataProviderRepository(cache),
            updateTrigger: updateTrigger,
            executionQueue: executionQueue,
            serialSyncQueue: historySyncQueue
        )
    }
}
