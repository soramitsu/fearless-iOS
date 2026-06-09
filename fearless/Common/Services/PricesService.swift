import Foundation
import SSFModels
import RobinHood

protocol PricesServiceProtocol {
    func setup()
    func updatePrices()
}

protocol PricesServiceDateProvider {
    var now: Date { get }
}

struct SystemPricesServiceDateProvider: PricesServiceDateProvider {
    var now: Date { Date() }
}

final class PricesService: PricesServiceProtocol {
    static let shared: PricesServiceProtocol = PricesService.create()
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let eventCenter: EventCenterProtocol
    private let dateProvider: PricesServiceDateProvider
    private var chainAssets: [ChainAsset] = []
    private var currencies: [SSFModels.Currency] = []
    private var lastRequestDate: Date?

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        eventCenter: EventCenterProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber = PriceLocalStorageSubscriberImpl.shared,
        dateProvider: PricesServiceDateProvider = SystemPricesServiceDateProvider()
    ) {
        self.chainRepository = chainRepository
        self.walletRepository = walletRepository
        self.operationQueue = operationQueue
        self.logger = logger
        self.eventCenter = eventCenter
        self.priceLocalSubscriber = priceLocalSubscriber
        self.dateProvider = dateProvider
    }

    func setup() {
        eventCenter.add(observer: self)
        let walletsOperation = walletRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let chainsOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let subscribeOperation = ClosureOperation { [weak self] in
            let wallets = try walletsOperation.extractNoCancellableResultData()
            let currencies = wallets.compactMap { $0.selectedCurrency }.uniq(predicate: { $0.id })

            let chains = try chainsOperation.extractNoCancellableResultData()
            let chainAssets = chains.map(\.chainAssets).reduce([], +).uniq(predicate: { $0.chainAssetId })

            self?.observePrices(for: chainAssets, currencies: currencies)
        }
        subscribeOperation.addDependency(walletsOperation)
        subscribeOperation.addDependency(chainsOperation)
        operationQueue.addOperations([subscribeOperation, walletsOperation, chainsOperation], waitUntilFinished: false)
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

extension PricesService: EventVisitorProtocol {
    func processChainSyncDidComplete(event: ChainSyncDidComplete) {
        let updatedChainAssets = event.newOrUpdatedChains.map(\.chainAssets).reduce([], +).uniq(predicate: { $0.chainAssetId })
        observePrices(for: updatedChainAssets, currencies: currencies)
    }

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        let updatedChainAssets = event.updatedChains.map(\.chainAssets).reduce([], +).uniq(predicate: { $0.chainAssetId })
        observePrices(for: updatedChainAssets, currencies: currencies)
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        let currency = event.account.selectedCurrency
        observePrices(for: chainAssets, currencies: [currency])
    }
}

extension PricesService {
    private static func create() -> PricesServiceProtocol {
        let chainRepository = ChainRepositoryFactory().createRepository()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let walletRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        return PricesService(
            chainRepository: AnyDataProviderRepository(chainRepository),
            walletRepository: AnyDataProviderRepository(walletRepository),
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            eventCenter: EventCenter.shared,
            priceLocalSubscriber: PriceLocalStorageSubscriberImpl.shared,
            dateProvider: SystemPricesServiceDateProvider()
        )
    }

    func observePrices(for chainAssets: [SSFModels.ChainAsset], currencies: [SSFModels.Currency]) {
        let oldAssets = self.chainAssets
        let uniqueAssets = chainAssets.filter { newAsset in
            !oldAssets.contains(newAsset)
        }
        let oldCurrencies = self.currencies
        let uniqueCurrencies = currencies.filter { newCurrency in
            !oldCurrencies.contains(newCurrency)
        }
        let now = dateProvider.now
        let timeFromLastRequest = now.timeIntervalSince(lastRequestDate ?? Date.distantPast)
        if uniqueAssets.isNotEmpty || uniqueCurrencies.isNotEmpty || timeFromLastRequest > 30 {
            let updatedAssets = oldAssets + uniqueAssets
            let updatedCurrencies = oldCurrencies + uniqueCurrencies

            pricesProvider = priceLocalSubscriber.subscribeToPrices(
                for: updatedAssets,
                currencies: updatedCurrencies,
                listener: self
            )
            self.chainAssets = updatedAssets
            self.currencies = updatedCurrencies
            lastRequestDate = now
        }
    }

    private func handle(prices _: [PriceData], for _: [ChainAsset]) {
        // Prices are consumed directly by UI formatters via wallet-selected currency.
        // Persisting into ChainModel assets is no longer supported here.
        eventCenter.notify(with: PricesUpdated())
    }

    private func handle(error: Error) {
        logger.error("Prices service failed to get prices: \(error.localizedDescription)")
    }
}
