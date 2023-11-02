import Foundation
import RobinHood
import SSFModels

protocol PriceProviderFactoryProtocol {
    func getPriceProvider(for priceId: AssetModel.PriceId, currency: Currency?) -> AnySingleValueProvider<PriceData>
    func getPricesProvider(for pricesIds: [AssetModel.PriceId], currency: Currency?) -> AnySingleValueProvider<[PriceData]>
    func getPricesProvider(for pricesIds: [AssetModel.PriceId], currencies: [Currency]?) -> AnySingleValueProvider<[PriceData]>
}

class PriceProviderFactory {
    static let shared = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

    private var providers: [AssetModel.PriceId: WeakWrapper] = [:]

    private let storageFacade: StorageFacadeProtocol
    private lazy var executionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }

    static func localIdentifier(for priceId: AssetModel.PriceId) -> String {
        "coingecko_price_\(priceId)"
    }
}

extension PriceProviderFactory: PriceProviderFactoryProtocol {
    func getPriceProvider(for priceId: AssetModel.PriceId, currency: Currency?) -> AnySingleValueProvider<PriceData> {
        clearIfNeeded()

        let identifier = Self.localIdentifier(for: priceId)

        if let provider = providers[identifier]?.target as? SingleValueProvider<PriceData> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let currencies = currency != nil ? [currency].compactMap { $0 } : nil
        let source = CoingeckoPriceSource(priceId: priceId, currencies: currencies)

        let trigger: DataProviderEventTrigger = [.onAddObserver, .onInitialization]
        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger
        )

        providers[identifier] = WeakWrapper(target: provider)

        return AnySingleValueProvider(provider)
    }

    func getPricesProvider(for pricesIds: [AssetModel.PriceId], currency: Currency?) -> AnySingleValueProvider<[PriceData]> {
        let identifier = pricesIds.sorted().joined(separator: ",")

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let currencies = currency != nil ? [currency].compactMap { $0 } : nil
        let source = CoingeckoPricesSource(pricesIds: pricesIds, currencies: currencies)

        let trigger: DataProviderEventTrigger = [.onAddObserver]
        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger,
            executionQueue: executionQueue
        )

        return AnySingleValueProvider(provider)
    }

    func getPricesProvider(for pricesIds: [AssetModel.PriceId], currencies: [Currency]?) -> AnySingleValueProvider<[PriceData]> {
        let identifier = pricesIds.sorted().joined(separator: ",")

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let source = CoingeckoPricesSource(pricesIds: pricesIds, currencies: currencies)

        let trigger: DataProviderEventTrigger = [.onAddObserver]
        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: trigger,
            executionQueue: executionQueue
        )

        return AnySingleValueProvider(provider)
    }
}
