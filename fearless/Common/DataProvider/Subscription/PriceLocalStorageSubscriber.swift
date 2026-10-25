import Foundation
import RobinHood
import SSFModels
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

protocol PriceLocalStorageSubscriber where Self: AnyObject {
    func subscribeToPrice(for chainAsset: ChainAsset, listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrice(for chainAsset: ChainAsset, currencies: [Currency]?, listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrices(for chainAssets: [ChainAsset], listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrices(for chainAssets: [ChainAsset], currencies: [Currency]?, listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]>
}

struct PriceLocalStorageSubscriberListener {
    enum Handler: Equatable {
        case price
        case prices
    }

    let listener: WeakWrapper
    let chainAssets: [ChainAsset]
    let currencies: [Currency]
    let handler: Handler
}

final class PriceLocalStorageSubscriberImpl: PriceLocalStorageSubscriber {
    static let shared = PriceLocalStorageSubscriberImpl()

    private let eventCenter = EventCenter.shared
    private let priceLocalSubscriber: PriceProviderFactoryProtocol
    private let chainsRepository: AsyncCoreDataRepositoryDefault<ChainModel, CDChain>

    private lazy var provider: AnySingleValueProvider<[PriceData]> = {
        setupProvider()
    }()

    private var remoteFetchTimer: Timer?
    private var listeners: [PriceLocalStorageSubscriberListener] = []
    private var sourcedCurrencyIds: Set<String> = []
    private var sourcedChainAssetIds: Set<ChainAssetId> = []
    private var chainAssets: [ChainAsset] = []

    init(
        priceLocalSubscriber: PriceProviderFactoryProtocol = PriceProviderFactory(),
        startAutomatically: Bool = true
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        chainsRepository = ChainRepositoryFactory().createAsyncRepository()

        if startAutomatically {
            setup()
        }
    }

    private func setup() {
        eventCenter.add(observer: self)
        refreshChainsAndSubscribe()
    }

    // MARK: - PriceLocalStorageSubscriber

    func subscribeToPrice(
        for chainAsset: ChainAsset,
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrice(for: chainAsset, currencies: nil, listener: listener)
    }

    func subscribeToPrices(
        for chainAssets: [ChainAsset],
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: chainAssets, currencies: nil, listener: listener)
    }

    func subscribeToPrice(
        for chainAsset: ChainAsset,
        currencies: [Currency]?,
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        performOnMainThread {
            self.appendListenerIfNeeded(
                listener,
                chainAssets: [chainAsset],
                currencies: currencies,
                handler: .price
            )
            let currentProvider = self.provider
            _ = self.updateProviderContextIfNeeded()
            self.refreshProviderIfPossible(currentProvider)
            return currentProvider
        }
    }

    func subscribeToPrices(
        for chainAssets: [ChainAsset],
        currencies: [Currency]?,
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        performOnMainThread {
            self.appendListenerIfNeeded(
                listener,
                chainAssets: chainAssets,
                currencies: currencies,
                handler: .prices
            )
            let currentProvider = self.provider
            _ = self.updateProviderContextIfNeeded()
            self.refreshProviderIfPossible(currentProvider)
            return currentProvider
        }
    }

    // MARK: - Private methods

    private func setupProvider() -> AnySingleValueProvider<[PriceData]> {
        dispatchPrecondition(condition: .onQueue(.main))

        let currencies = providerCurrencies()
        let chainAssets = providerChainAssets()
        sourcedCurrencyIds = Set(currencies.map(\.id))
        sourcedChainAssetIds = Set(chainAssets.map(\.chainAssetId))

        let priceProvider = priceLocalSubscriber.getPricesProvider(
            currencies: currencies,
            chainAssets: chainAssets
        )

        let updateClosure = { [weak self, weak priceProvider] (changes: [DataProviderChange<[PriceData]>]) in
            guard let self, let priceProvider else {
                return
            }

            if let prices: [PriceData] = changes.reduceToLastChange() {
                self.handleResult(for: .success(prices))
                self.clearListenersIfNeeded()
            }

            self.refreshPendingContextIfNeeded(using: priceProvider)
        }

        let failureClosure = { [weak self, weak priceProvider] (error: Error) in
            guard let self, let priceProvider else {
                return
            }

            self.handleResult(for: .failure(error))
            self.clearListenersIfNeeded()
            self.refreshPendingContextIfNeeded(using: priceProvider)
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return priceProvider
    }

    @discardableResult
    private func updateProviderContextIfNeeded() -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))

        let currencies = providerCurrencies()
        let chainAssets = providerChainAssets()
        let currencyIds = Set(currencies.map(\.id))
        let chainAssetIds = Set(chainAssets.map(\.chainAssetId))
        let needsUpdate = sourcedCurrencyIds != currencyIds
            || sourcedChainAssetIds != chainAssetIds

        guard needsUpdate else {
            return false
        }

        remoteFetchTimer?.invalidate()
        remoteFetchTimer = nil
        sourcedCurrencyIds = currencyIds
        sourcedChainAssetIds = chainAssetIds
        priceLocalSubscriber.updatePricesProvider(
            currencies: currencies,
            chainAssets: chainAssets
        )
        return true
    }

    private func refreshProviderIfPossible(
        _ currentProvider: AnySingleValueProvider<[PriceData]>
    ) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard remoteFetchTimer == nil else {
            return
        }

        remoteFetchTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: false
        ) { [weak self] timer in
            timer.invalidate()
            self?.remoteFetchTimer = nil
        }
        currentProvider.refresh()
    }

    private func refreshPendingContextIfNeeded(
        using currentProvider: AnySingleValueProvider<[PriceData]>
    ) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard priceLocalSubscriber.pricesProviderNeedsFollowUpFetch() else {
            return
        }

        remoteFetchTimer?.invalidate()
        remoteFetchTimer = nil
        refreshProviderIfPossible(currentProvider)
    }

    private func handleResult(for pricesResult: Result<[PriceData]?, Error>) {
        dispatchPrecondition(condition: .onQueue(.main))

        switch pricesResult {
        case let .success(prices):
            handleSuccess(prices: prices)
        case let .failure(error):
            handleFailure(error: error)
        }
    }

    private func handleSuccess(prices: [PriceData]?) {
        guard let prices else {
            return
        }

        let validPrices = prices.filter {
            PriceValueValidator.isStrictlyPositiveDecimal(
                $0.price,
                maximumBytes: 256
            )
        }
        AssetPriceCache.shared.merge(validPrices)

        listeners.forEach { wrapper in
            guard
                let listener = wrapper.listener.target as? PriceLocalSubscriptionHandler
            else {
                return
            }
            let finalValue = validPrices.filter { price in
                wrapper.chainAssets.contains { $0.asset.priceId == price.priceId }
                    && wrapper.currencies.contains { $0.id == price.currencyId }
            }

            listener.handlePrices(result: .success(finalValue), for: wrapper.chainAssets)
        }
    }

    private func handleFailure(error: Error) {
        listeners.forEach { wrapper in
            guard let listener = wrapper.listener.target as? PriceLocalSubscriptionHandler else {
                return
            }
            listener.handlePrices(result: .failure(error), for: wrapper.chainAssets)
        }
    }

    private func clearListenersIfNeeded() {
        listeners = listeners.filter { $0.listener.target != nil }
    }

    private func appendListenerIfNeeded(
        _ listener: PriceLocalSubscriptionHandler,
        chainAssets: [ChainAsset],
        currencies: [Currency]?,
        handler: PriceLocalStorageSubscriberListener.Handler
    ) {
        let resolvedCurrencies: [Currency]
        if let currencies {
            resolvedCurrencies = currencies
        } else if let selectedCurrency = SelectedWalletSettings.shared.value?.selectedCurrency {
            resolvedCurrencies = [selectedCurrency]
        } else {
            return
        }

        let existingListener = listeners.first {
            $0.listener.target === listener
        }
        let requestedChainAssetIds = Set(chainAssets.map(\.chainAssetId))
        let existingChainAssetIds = Set(existingListener?.chainAssets.map(\.chainAssetId) ?? [])

        guard
            existingListener?.currencies != resolvedCurrencies
            || existingChainAssetIds != requestedChainAssetIds
            || existingListener?.handler != handler
        else {
            return
        }

        listeners.removeAll { $0.listener.target === listener }
        listeners.append(
            PriceLocalStorageSubscriberListener(
                listener: WeakWrapper(target: listener),
                chainAssets: chainAssets,
                currencies: resolvedCurrencies,
                handler: handler
            )
        )
    }

    private func providerCurrencies() -> [Currency] {
        listeners
            .flatMap(\.currencies)
            .uniq(predicate: { $0.id })
    }

    private func providerChainAssets() -> [ChainAsset] {
        (chainAssets + listeners.flatMap(\.chainAssets))
            .uniq(predicate: { $0.chainAssetId })
    }

    private func refreshChainsAndSubscribe() {
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let chains = try await chainsRepository.fetchAll()
                let chainAssets = chains
                    .flatMap(\.chainAssets)
                    .uniq(predicate: { $0.chainAssetId })

                await MainActor.run {
                    self.chainAssets = chainAssets
                    let currentProvider = self.provider
                    _ = self.updateProviderContextIfNeeded()
                    self.refreshProviderIfPossible(currentProvider)
                }
            } catch {
                Logger.shared.error("PRICE_CHAIN_CONTEXT_FETCH_FAILED")
            }
        }
    }

    private func performOnMainThread<T>(_ block: () -> T) -> T {
        if Thread.isMainThread {
            return block()
        }

        return DispatchQueue.main.sync(execute: block)
    }
}

extension PriceLocalStorageSubscriberImpl: EventVisitorProtocol {
    func processChainSyncDidComplete(event: ChainSyncDidComplete) {
        guard event.newOrUpdatedChains.isNotEmpty else {
            return
        }

        refreshChainsAndSubscribe()
    }
}
