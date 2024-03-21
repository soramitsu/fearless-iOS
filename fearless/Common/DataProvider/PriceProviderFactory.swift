import Foundation
import RobinHood
import SSFModels
import SSFSingleValueCache

protocol PriceProviderFactoryProtocol {
    func getPricesProvider(currencies: [Currency]?) throws -> AnySingleValueProvider<[PriceData]>
}

class PriceProviderFactory {
    static let shared = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

    private var providers: [AssetModel.PriceId: WeakWrapper] = [:]
    private var remoteFetchTimer: Timer?

    private let storageFacade: StorageFacadeProtocol
    private lazy var executionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }
}

extension PriceProviderFactory: PriceProviderFactoryProtocol {
    func getPricesProvider(currencies: [Currency]?) throws -> AnySingleValueProvider<[SSFModels.PriceData]> {
        let identifier = currencies?.compactMap { $0.id }.sorted().joined(separator: ".") ?? PriceDataSource.defaultIdentifier

        if let provider = providers[identifier]?.target as? SingleValueProvider<[PriceData]> {
            if remoteFetchTimer == nil {
                DispatchQueue.main.async {
                    self.remoteFetchTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false, block: { [weak self] timer in
                        timer.invalidate()
                        self?.remoteFetchTimer = nil
                    })
                }
                provider.refresh()
            }
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = try SingleValueCacheRepositoryFactoryDefault().createSingleValueCacheRepository()
        let source = PriceDataSource(currencies: currencies)
        let trigger: DataProviderEventTrigger = [.onInitialization, .onFetchPage]
        let provider = SingleValueProvider(
            targetIdentifier: source.identifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger,
            executionQueue: executionQueue
        )

        providers[identifier] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }
}
