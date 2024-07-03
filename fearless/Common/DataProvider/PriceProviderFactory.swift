import Foundation
import RobinHood
import SSFModels
import SSFSingleValueCache

protocol PriceProviderFactoryProtocol {
    func getPricesProvider(currencies: [Currency]?) -> AnySingleValueProvider<[PriceData]>
}

class PriceProviderFactory {
    static let shared = PriceProviderFactory()

    private var currentProvider: AnySingleValueProvider<[SSFModels.PriceData]>?

    private lazy var executionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
}

extension PriceProviderFactory: PriceProviderFactoryProtocol {
    func getPricesProvider(currencies: [Currency]?) -> AnySingleValueProvider<[SSFModels.PriceData]> {
        if let currentProvider {
            return currentProvider
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
        let source = PriceDataSource(currencies: currencies)
        let trigger: DataProviderEventTrigger = [.onFetchPage]
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
