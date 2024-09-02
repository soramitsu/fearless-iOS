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
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let logger: Logger
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let eventCenter: EventCenter
    private var chainAssets: [ChainAsset] = []
    private var currencies: [SSFModels.Currency] = []
    private var lastRequestDate: Date?

    private init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        logger: Logger,
        eventCenter: EventCenter
    ) {
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.logger = logger
        self.eventCenter = eventCenter
    }

    func startPricesObserving(for chainAssets: [SSFModels.ChainAsset], currencies: [SSFModels.Currency]) {
        let oldAssets = self.chainAssets
        let uniqueAssets = chainAssets.filter { newAsset in
            !oldAssets.contains(newAsset)
        }
        let oldCurrencies = self.currencies
        let uniqueCurencies = currencies.filter { newCurrency in
            !oldCurrencies.contains(newCurrency)
        }
        let timeFromLastRequst = Date().timeIntervalSince(lastRequestDate ?? Date.distantPast)
        if uniqueAssets.isNotEmpty || uniqueCurencies.isNotEmpty || timeFromLastRequst > 30 {
            let updatedAssets = oldAssets + uniqueAssets
            let updatedCurrencies = currencies + uniqueCurencies

            pricesProvider = priceLocalSubscriber.subscribeToPrices(
                for: updatedAssets,
                currencies: updatedCurrencies,
                listener: self
            )
            self.chainAssets = updatedAssets
            self.currencies = currencies
            lastRequestDate = Date()
        }
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
        var updatedChains: [ChainModel] = []
        let uniqChains: [ChainModel] = chainAssets.compactMap { $0.chain }.uniq { $0.chainId }
        uniqChains.forEach { chain in
            var updatedAssets: [AssetModel] = []
            chain.chainAssets.forEach { chainAsset in
                let assetPrices = prices.filter { $0.priceId == chainAsset.asset.priceId }
                let updatedAsset = chainAsset.asset.replacingPrice(assetPrices)
                updatedAssets.append(updatedAsset)
            }
            let updatedChain = chain.replacing(updatedAssets)
            updatedChains.append(updatedChain)
        }
        let saveOperation = chainRepository.saveOperation({
            updatedChains
        }, {
            []
        })
        operationQueue.addOperation(saveOperation)
    }

    func handle(error: Error) {
        logger.error("Prices service failed to get prices: \(error.localizedDescription)")
    }
}

private extension PricesService {
    static func create() -> PricesServiceProtocol {
        let repository = ChainRepositoryFactory().createRepository()
        return PricesService(
            chainRepository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            eventCenter: EventCenter.shared
        )
    }
}
