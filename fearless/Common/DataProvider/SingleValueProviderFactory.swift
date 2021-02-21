import Foundation
import RobinHood

protocol SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> SingleValueProvider<PriceData>
}

final class SingleValueProviderFactory {
    static let shared = SingleValueProviderFactory(facade: SubstrateDataStorageFacade.shared)

    private var providers: [String: WeakWrapper] = [:]

    let facade: StorageFacadeProtocol

    init(facade: StorageFacadeProtocol) {
        self.facade = facade
    }

    private func priceIdentifier(for assetId: WalletAssetId) -> String {
        assetId.rawValue + "PriceId"
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }
}

extension SingleValueProviderFactory: SingleValueProviderFactoryProtocol {
    func getPriceProvider(for assetId: WalletAssetId) -> SingleValueProvider<PriceData> {
        clearIfNeeded()

        let identifier = priceIdentifier(for: assetId)

        if let provider = providers[identifier]?.target as? SingleValueProvider<PriceData> {
            return provider
        }

        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            facade.createRepository()

        let source = SubscanPriceSource(assetId: assetId)

        let trigger: DataProviderEventTrigger = [.onAddObserver, .onInitialization]
        let provider = SingleValueProvider(targetIdentifier: identifier,
                                           source: AnySingleValueProviderSource(source),
                                           repository: AnyDataProviderRepository(repository),
                                           updateTrigger: trigger)

        providers[identifier] = WeakWrapper(target: provider)

        return provider
    }
}
