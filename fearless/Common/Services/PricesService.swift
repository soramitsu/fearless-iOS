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
    private let eventCenter: EventCenter

    private init(
        assetRepository: AnyDataProviderRepository<AssetModel>,
        operationQueue: OperationQueue,
        logger: Logger,
        eventCenter: EventCenter
    ) {
        self.assetRepository = assetRepository
        self.operationQueue = operationQueue
        self.logger = logger
        self.eventCenter = eventCenter
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

    func handlePrices(result: Result<[PriceData], Error>, for chainAssets: [ChainAsset]) {
        switch result {
        case let .success(priceDatas):
            handle(prices: priceDatas, for: chainAssets)
        case let .failure(error):
            handle(error: error)
        }
    }
}

private extension PricesService {
    func handle(prices: [PriceData], for chainAssets: [ChainAsset]) {
        var updatedAssets: [AssetModel] = []
        chainAssets.forEach { chainAsset in
            let assetPrices = prices.filter { price in
                price.priceId == chainAsset.asset.priceId
            }
            let updatedAsset = chainAsset.asset.replacingPrice(assetPrices)
            updatedAssets.append(updatedAsset)
        }
        let saveOperation = assetRepository.saveOperation({
            updatedAssets
        }, {
            []
        })
        saveOperation.completionBlock = { [weak self] in
            self?.eventCenter.notify(with: PricesUpdated())
        }
        operationQueue.addOperation(saveOperation)
    }

    func handle(error: Error) {
        logger.error("Prices service failed to get prices: \(error.localizedDescription)")
    }
}

private extension PricesService {
    static func create() -> PricesServiceProtocol {
        let repository = AssetRepositoryFactory().createRepository()
        return PricesService(
            assetRepository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            eventCenter: EventCenter.shared
        )
    }
}

extension AssetModel: Identifiable {
    public var identifier: String {
        id
    }
}
