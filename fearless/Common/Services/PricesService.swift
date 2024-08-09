import SSFModels
import RobinHood

protocol PricesServiceProtocol {
    func startPricesObserving(for chainAssets: [ChainAsset], currencies: [Currency])
    func updatePrices()
}

final class PricesService: PricesServiceProtocol {
    static let shared: PricesServiceProtocol = PricesService.create()
    private let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
    private let assetRepository: AnyDataProviderRepository<AssetModel>
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?

    private init(assetRepository: AnyDataProviderRepository<AssetModel>) {
        self.assetRepository = assetRepository
    }

    func startPricesObserving(for chainAssets: [SSFModels.ChainAsset], currencies: [SSFModels.Currency]) {
        pricesProvider = priceLocalSubscriber.subscribeToPrices(
            for: chainAssets,
            currencies: currencies,
            listener: self
        )
    }

    func updatePrices() {
        pricesProvider?.refresh()
    }
}

extension PricesService: PriceLocalSubscriptionHandler {
    func handlePrice(
        result _: Result<PriceData?, Error>,
        chainAsset _: ChainAsset
    ) {}

    func handlePrices(result _: Result<[PriceData], Error>) {
//        let assets = assetRepository.fetchAll()
    }
}

private extension PricesService {
    static func create() -> PricesServiceProtocol {
        let repositoryFacade = SubstrateDataStorageFacade.shared
        let mapper: CodableCoreDataMapper<AssetModel, CDAsset> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDAsset.id))
        let repository: CoreDataRepository<AssetModel, CDAsset> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )
        return PricesService(assetRepository: AnyDataProviderRepository(repository))
    }
}

extension AssetModel: Identifiable {
    public var identifier: String {
        id
    }
}
