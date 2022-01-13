import Foundation
import RobinHood
import CommonWallet

protocol HistoryDataProviderFactoryProtocol {
    func createDataProvider(
        for address: String,
        asset: AssetModel,
        chain: ChainModel,
        targetIdentifier: String,
        using _: DispatchQueue
    ) throws
        -> SingleValueProvider<AssetTransactionPageData>
}

class HistoryDataProviderFactory: BaseDataProviderFactory, HistoryDataProviderFactoryProtocol {
    let historySyncQueue = DispatchQueue(label: "co.jp.soramitsu.wallet.cache.history.queue")
    let executionQueue = OperationQueue()
    let operationFactory: HistoryOperationFactoryProtocol

    init(
        cacheFacade: StorageFacadeProtocol,
        operationFactory: HistoryOperationFactoryProtocol
    ) {
        self.operationFactory = operationFactory

        super.init(cacheFacade: cacheFacade)
    }

    enum Constants {
        static let historyDefaultPageSize = 100
    }

    func createDataProvider(
        for address: String,
        asset: AssetModel,
        chain: ChainModel,
        targetIdentifier: String,
        using _: DispatchQueue
    ) throws
        -> SingleValueProvider<AssetTransactionPageData> {
        let pagination = Pagination(count: Constants.historyDefaultPageSize)

        let source: AnySingleValueProviderSource<AssetTransactionPageData> =
            AnySingleValueProviderSource {
                var filter = WalletHistoryRequest()
                filter.assets = [asset.identifier]
                let operation = self.operationFactory
                    .fetchSubqueryHistoryOperation(
                        asset: asset,
                        chain: chain,
                        address: address,
                        request: filter,
                        pagination: pagination
                    )
                return operation
            }

        let cache = createSingleValueCache()

        let updateTrigger = DataProviderEventTrigger.onAll

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
