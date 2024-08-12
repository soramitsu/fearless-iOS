import Foundation
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
    private let operationQueue: OperationQueue
    private let logger: Logger
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private var assets: [AssetModel] = []

    private init(
        assetRepository: AnyDataProviderRepository<AssetModel>,
        operationQueue: OperationQueue,
        logger: Logger
    ) {
        self.assetRepository = assetRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func startPricesObserving(for chainAssets: [SSFModels.ChainAsset], currencies: [SSFModels.Currency]) {
        pricesProvider = priceLocalSubscriber.subscribeToPrices(
            for: chainAssets,
            currencies: currencies,
            listener: self
        )
        self.assets = chainAssets.map { $0.asset }.uniq(predicate: { assetModel in
            assetModel.id
        })
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

    func handlePrices(result: Result<[PriceData], Error>) {
        switch result {
        case .success(let priceDatas):
            handle(prices: priceDatas)
        case .failure(let error):
            handle(error: error)
        }
    }
}

private extension PricesService {
    func handle(prices: [PriceData]) {
        var updatedAssets: [AssetModel] = []
        assets.forEach { asset in
            let assetPrices = prices.filter { price in
                price.priceId == asset.priceId
            }
            let updatedAsset = asset.replacingPrice(assetPrices)
            updatedAssets.append(updatedAsset)
        }
        let saveOperation = assetRepository.saveOperation({
            updatedAssets
        }, {
            []
        })
        operationQueue.addOperation(saveOperation)
    }
    
    func handle(error: Error) {
        logger.error("Prices service failed to get prices")
    }
}

private extension PricesService {
    static func create() -> PricesServiceProtocol {
        let repository = AssetRepositoryFactory().createRepository()
        return PricesService(
            assetRepository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }
}

extension AssetModel: Identifiable {
    public var identifier: String {
        id
    }
}
