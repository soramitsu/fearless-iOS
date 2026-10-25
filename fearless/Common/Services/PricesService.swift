import Foundation
import SSFModels
import RobinHood

protocol PricesServiceProtocol {
    func setup()
    func updatePrices()
}

final class PricesService: PricesServiceProtocol {
    static let shared: PricesServiceProtocol = PricesService.create()
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationQueue: OperationQueue
    private let logger: Logger
    private var subscriptionRevision: UInt64 = 0
    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private let eventCenter: EventCenter
    private var chainAssets: [ChainAsset] = []
    private var currencies: [SSFModels.Currency] = []
    private var lastRequestDate: Date?

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        logger: Logger,
        eventCenter: EventCenter,
        priceLocalSubscriber: PriceLocalStorageSubscriber = PriceLocalStorageSubscriberImpl.shared
    ) {
        self.chainRepository = chainRepository
        self.walletRepository = walletRepository
        self.operationQueue = operationQueue
        self.logger = logger
        self.eventCenter = eventCenter
        self.priceLocalSubscriber = priceLocalSubscriber
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

            self?.withState { service in
                service.observePrices(for: chainAssets, currencies: currencies)
            }
        }
        subscribeOperation.addDependency(walletsOperation)
        subscribeOperation.addDependency(chainsOperation)
        operationQueue.addOperations([subscribeOperation, walletsOperation, chainsOperation], waitUntilFinished: false)
    }

    func updatePrices() {
        withState { service in
            service.pricesProvider?.refresh()
        }
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
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        withState { service in
            service.observePrices(for: service.chainAssets, currencies: [event.account.selectedCurrency])
        }
    }

    func processChainSyncDidComplete(event: ChainSyncDidComplete) {
        withState { service in
            let updatedChainAssets = event.newOrUpdatedChains.map(\.chainAssets).reduce([], +).uniq(predicate: { $0.chainAssetId })
            service.observePrices(for: updatedChainAssets, currencies: service.currencies)
        }
    }

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        withState { service in
            let updatedChainAssets = event.updatedChains.map(\.chainAssets).reduce([], +).uniq(predicate: { $0.chainAssetId })
            service.observePrices(for: updatedChainAssets, currencies: service.currencies)
        }
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        withState { service in
            service.observePrices(for: service.chainAssets, currencies: [event.account.selectedCurrency])
        }
    }

    func processLogout() {
        ExactAssetPriceCache.shared.clear()
    }
}

private extension PricesService {
    // The subscriber also owns its subscriptions on Main. Keep the service scope
    // there so a background repository completion never blocks Main through a lock.
    func withState(_ update: @escaping (PricesService) -> Void) {
        if Thread.isMainThread {
            update(self)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                update(self)
            }
        }
    }

    static func create() -> PricesServiceProtocol {
        let chainRepository = ChainRepositoryFactory().createRepository()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let walletRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        return PricesService(
            chainRepository: AnyDataProviderRepository(chainRepository),
            walletRepository: AnyDataProviderRepository(walletRepository),
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            eventCenter: EventCenter.shared
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
        let timeFromLastRequest = Date().timeIntervalSince(lastRequestDate ?? Date.distantPast)
        if uniqueAssets.isNotEmpty || uniqueCurrencies.isNotEmpty || timeFromLastRequest > 30 {
            let updatedAssets = oldAssets + uniqueAssets
            let updatedCurrencies = oldCurrencies + uniqueCurrencies

            // Publish the accumulated scope before subscribing: a provider may
            // synchronously deliver an event that adds another currency.
            self.chainAssets = updatedAssets
            self.currencies = updatedCurrencies
            lastRequestDate = Date()
            subscriptionRevision &+= 1
            let revision = subscriptionRevision
            let provider = priceLocalSubscriber.subscribeToPrices(
                for: updatedAssets,
                currencies: updatedCurrencies,
                listener: self
            )
            if revision == subscriptionRevision {
                pricesProvider = provider
            }
        }
    }

    func handle(prices: [PriceData], for _: [ChainAsset]) {
        // Publish the exact keyed values before notifying consumers. ChainModel's
        // legacy scalar price cannot preserve fiat currency identity.
        ExactAssetPriceCache.shared.upsert(prices)
        eventCenter.notify(with: PricesUpdated())
    }

    func handle(error: Error) {
        logger.error("Prices service failed to get prices: \(error.localizedDescription)")
    }
}
