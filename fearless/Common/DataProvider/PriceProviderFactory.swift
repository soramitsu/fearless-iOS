import Foundation
import RobinHood
import SSFModels
import SSFSingleValueCache

protocol PriceProviderFactoryProtocol {
    func getPricesProvider(currencies: [Currency]?, chainAssets: [ChainAsset]) -> AnySingleValueProvider<[PriceData]>
    func updatePricesProvider(currencies: [Currency]?, chainAssets: [ChainAsset])
    func pricesProviderNeedsFollowUpFetch() -> Bool
}

final class PriceProviderFactory: PriceProviderFactoryProtocol {
    private lazy var executionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private let providerLock = NSLock()
    private var priceDataSource: PriceDataSource?
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?

    func getPricesProvider(currencies: [Currency]?, chainAssets: [ChainAsset]) -> AnySingleValueProvider<[SSFModels.PriceData]> {
        providerLock.lock()
        defer { providerLock.unlock() }

        if let pricesProvider, let priceDataSource {
            priceDataSource.update(currencies: currencies, chainAssets: chainAssets)
            return pricesProvider
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
        let repositoryWrapper = AnyDataProviderRepository(repository)
        let source = PriceDataSource(
            currencies: currencies,
            chainAssets: chainAssets,
            priceCacheReader: PriceDataCacheReader(
                repository: repositoryWrapper,
                identifier: PriceDataSource.defaultIdentifier
            )
        )
        let trigger: DataProviderEventTrigger = [.onFetchPage, .onAddObserver]
        let provider = SingleValueProvider(
            targetIdentifier: PriceDataSource.defaultIdentifier,
            source: AnySingleValueProviderSource(source),
            repository: repositoryWrapper,
            updateTrigger: trigger,
            executionQueue: executionQueue
        )

        let typeErasedProvider = AnySingleValueProvider(provider)
        priceDataSource = source
        pricesProvider = typeErasedProvider
        return typeErasedProvider
    }

    func updatePricesProvider(
        currencies: [Currency]?,
        chainAssets: [ChainAsset]
    ) {
        providerLock.lock()
        priceDataSource?.update(currencies: currencies, chainAssets: chainAssets)
        providerLock.unlock()
    }

    func pricesProviderNeedsFollowUpFetch() -> Bool {
        providerLock.lock()
        defer { providerLock.unlock() }
        return priceDataSource?.needsFollowUpFetch == true
    }
}
