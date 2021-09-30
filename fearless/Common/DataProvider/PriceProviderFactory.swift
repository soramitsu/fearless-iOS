import Foundation
import RobinHood

protocol PriceProviderFactoryProtocol {
    func getPriceProvider(for priceId: AssetModel.PriceId) -> AnySingleValueProvider<PriceData>
}

class PriceProviderFactory {
    static let shared = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

    private var providers: [AssetModel.PriceId: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol

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
    func getPriceProvider(for priceId: AssetModel.PriceId) -> AnySingleValueProvider<PriceData> {
        clearIfNeeded()

        let identifier = Self.localIdentifier(for: priceId)

        if let provider = providers[identifier]?.target as? SingleValueProvider<PriceData> {
            return AnySingleValueProvider(provider)
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            storageFacade.createRepository()

        let source = CoingeckoPriceSource(priceId: priceId)

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
}
