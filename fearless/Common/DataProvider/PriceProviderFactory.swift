import Foundation
import RobinHood
import SSFModels
import SSFSingleValueCache

protocol PriceProviderFactoryProtocol {
    func getPricesProvider(currencies: [Currency]?, chainAssets: [ChainAsset]) -> AnySingleValueProvider<[PriceData]>
}

final class PriceProviderFactory: PriceProviderFactoryProtocol {
    private lazy var executionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    func getPricesProvider(currencies: [Currency]?, chainAssets: [ChainAsset]) -> AnySingleValueProvider<[SSFModels.PriceData]> {
        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
        let source = PriceDataSource(currencies: currencies, chainAssets: chainAssets)
        let trigger: DataProviderEventTrigger = [.onFetchPage, .onAddObserver]
        let provider = SingleValueProvider(
            targetIdentifier: PriceDataSource.defaultIdentifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger,
            executionQueue: executionQueue
        )

        return AnySingleValueProvider(provider)
    }
}
