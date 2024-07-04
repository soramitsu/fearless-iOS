import Foundation
import RobinHood
import SSFModels

protocol PriceLocalStorageSubscriber where Self: AnyObject {
    func subscribeToPrice(for chainAsset: ChainAsset, listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrice(for chainAsset: ChainAsset, currencies: [Currency]?, listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrices(for chainAssets: [ChainAsset], listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrices(for chainAssets: [ChainAsset], currencies: [Currency]?, listener: PriceLocalSubscriptionHandler) -> AnySingleValueProvider<[PriceData]>
}

struct PriceLocalStorageSubscriberListener {
    let listener: WeakWrapper
    let chainAssets: [ChainAsset]
    let currencies: [Currency]
}

final class PriceLocalStorageSubscriberImpl: PriceLocalStorageSubscriber {
    static let shared = PriceLocalStorageSubscriberImpl()

    private lazy var provider: AnySingleValueProvider<[PriceData]> = {
        setupProvider()
    }()

    private lazy var priceLocalSubscriber: PriceProviderFactoryProtocol = {
        PriceProviderFactory()
    }()

    private var remoteFetchTimer: Timer?
    private var fetchOperation: CompoundOperationWrapper<[PriceData]?>?

    private var listeners: [PriceLocalStorageSubscriberListener] = []
    private var sourcedCurrencies: Set<Currency> = []

    private init() {}

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
        appendLisnenerIfNeeded(listener, chainAssets: [chainAsset], currencies: currencies)
        guard !didUpdateProvider(for: currencies) else {
            return provider
        }
        refreshProviderIfPossible()
        return provider
    }

    func subscribeToPrices(
        for chainAssets: [ChainAsset],
        currencies: [Currency]?,
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        appendLisnenerIfNeeded(listener, chainAssets: chainAssets, currencies: currencies)
        guard !didUpdateProvider(for: currencies) else {
            return provider
        }
        refreshProviderIfPossible()
        return provider
    }

    // MARK: - Private methods

    private func refreshProviderIfPossible() {
        if remoteFetchTimer == nil {
            DispatchQueue.main.async {
                self.remoteFetchTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false, block: { [weak self] timer in
                    timer.invalidate()
                    self?.remoteFetchTimer = nil
                })
            }
            provider.refresh()
        } else if fetchOperation == nil {
            fetchOperation = provider.fetch { [weak self] result in
                guard let result else { return }
                self?.handleResult(for: result)
                self?.fetchOperation = nil
            }
        }
    }

    private func setupProvider() -> AnySingleValueProvider<[PriceData]> {
        let providerCurrencies = listeners.map { $0.currencies }.compactMap { $0 }.reduce([], +).uniq(predicate: { $0.id })
        let priceProvider = priceLocalSubscriber.getPricesProvider(currencies: providerCurrencies)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[PriceData]>]) in
            guard let prices: [PriceData] = changes.reduceToLastChange() else {
                return
            }
            self?.handleResult(for: .success(prices))
            self?.clearListenersIfNeeded()
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.handleResult(for: .failure(error))
            self?.clearListenersIfNeeded()
        }

        let options = DataProviderObserverOptions(
            notifyIfNoDiff: true
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

    private func didUpdateProvider(for currencies: [Currency]?) -> Bool {
        let set = Set(currencies ?? [])
        let symmetricDifference = sourcedCurrencies.symmetricDifference(set)
        if symmetricDifference.isNotEmpty {
            remoteFetchTimer?.invalidate()
            remoteFetchTimer = nil
            provider = setupProvider()
        }
        return symmetricDifference.isNotEmpty
    }

    private func handleResult(for pricesResult: Result<[PriceData]?, Error>) {
        switch pricesResult {
        case let .success(prices):
            handleSuccess(prices: prices)
        case let .failure(error):
            handleFailure(error: error)
        }
    }

    private func handleSuccess(prices: [PriceData]?) {
        listeners.forEach { wrapper in
            guard
                let listener = wrapper.listener.target as? PriceLocalSubscriptionHandler,
                let prices
            else {
                return
            }
            let finalValue = prices.filter { price in
                wrapper.chainAssets.contains(where: { $0.asset.priceId == price.priceId }) == true
                    && wrapper.currencies.contains(where: { $0.id == price.currencyId }) == true
            }

            if wrapper.chainAssets.count == 1, let chainAsset = wrapper.chainAssets.first, let priceData = finalValue.first {
                listener.handlePrice(result: .success(priceData), chainAsset: chainAsset)
            } else {
                listener.handlePrices(result: .success(finalValue))
            }
        }
    }

    private func handleFailure(error: Error) {
        listeners.forEach { wrapper in
            guard let listener = wrapper.listener.target as? PriceLocalSubscriptionHandler else {
                return
            }
            if wrapper.chainAssets.count == 1, let chainAsset = wrapper.chainAssets.first {
                listener.handlePrice(result: .failure(error), chainAsset: chainAsset)
            } else {
                listener.handlePrices(result: .failure(error))
            }
        }
    }

    private func clearListenersIfNeeded() {
        listeners = listeners.filter { $0.listener.target != nil }
    }

    private func appendLisnenerIfNeeded(
        _ listener: PriceLocalSubscriptionHandler,
        chainAssets: [ChainAsset],
        currencies: [Currency]?
    ) {
        let existListener = listeners.first { wrapper in
            wrapper.listener.target === listener
        }
        guard existListener == nil || existListener?.currencies != currencies, let wallet = SelectedWalletSettings.shared.value else {
            return
        }
        listeners.removeAll(where: { $0.listener.target === existListener?.listener.target })
        let listener = PriceLocalStorageSubscriberListener(
            listener: WeakWrapper(target: listener),
            chainAssets: chainAssets,
            currencies: currencies ?? [wallet.selectedCurrency]
        )
        listeners.append(listener)
    }
}
