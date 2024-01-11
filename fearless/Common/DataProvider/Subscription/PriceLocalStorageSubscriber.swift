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
}

final class PriceLocalStorageSubscriberImpl: PriceLocalStorageSubscriber {
    static let shared = PriceLocalStorageSubscriberImpl()

    private lazy var priceLocalSubscriber: PriceProviderFactoryProtocol = {
        PriceProviderFactory.shared
    }()

    private var listeners: [PriceLocalStorageSubscriberListener] = []

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
        appendLisnenerIfNeeded(listener, chainAssets: [chainAsset])
        let priceProvider = priceLocalSubscriber.getPricesProvider(currencies: currencies)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[PriceData]>]) in

            self?.listeners.forEach { wrapper in
                guard
                    let listener = wrapper.listener.target as? PriceLocalSubscriptionHandler,
                    let finalValue = changes.reduceToLastChange()?.first(where: { price in wrapper.chainAssets.contains(where: { $0.asset.priceId == price.priceId }) == true })
                else {
                    return
                }
                listener.handlePrice(result: .success(finalValue), chainAsset: chainAsset)
            }
            self?.clearListenersIfNeeded()
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.listeners.forEach { wrapper in
                guard
                    let listener = wrapper.listener.target as? PriceLocalSubscriptionHandler,
                    let chainAsset = wrapper.chainAssets.first
                else {
                    return
                }
                listener.handlePrice(result: .failure(error), chainAsset: chainAsset)
            }
            self?.clearListenersIfNeeded()
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        priceProvider.removeObserver(self)
        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return priceProvider
    }

    func subscribeToPrices(
        for chainAssets: [ChainAsset],
        currencies: [Currency]?,
        listener: PriceLocalSubscriptionHandler
    ) -> AnySingleValueProvider<[PriceData]> {
        appendLisnenerIfNeeded(listener, chainAssets: chainAssets)
        let priceProvider = priceLocalSubscriber.getPricesProvider(currencies: currencies)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[PriceData]>]) in
            self?.listeners.forEach { wrapper in
                guard
                    let listener = wrapper.listener.target as? PriceLocalSubscriptionHandler,
                    let finalValue = changes.reduceToLastChange()?.filter({ price in wrapper.chainAssets.contains(where: { $0.asset.priceId == price.priceId }) == true })
                else {
                    return
                }
                listener.handlePrices(result: .success(finalValue))
            }
            self?.clearListenersIfNeeded()
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.listeners.forEach { wrapper in
                guard let listener = wrapper.listener.target as? PriceLocalSubscriptionHandler else {
                    return
                }
                listener.handlePrices(result: .failure(error))
            }
            self?.clearListenersIfNeeded()
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        priceProvider.removeObserver(self)
        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return priceProvider
    }

    // MARK: - Private methods

    private func clearListenersIfNeeded() {
        listeners = listeners.filter { $0.listener.target != nil }
    }

    private func appendLisnenerIfNeeded(_ listener: PriceLocalSubscriptionHandler, chainAssets: [ChainAsset]) {
        let existListener = listeners.first { wrapper in
            wrapper.listener.target === listener
        }
        guard existListener == nil else {
            return
        }
        let listener = PriceLocalStorageSubscriberListener(
            listener: WeakWrapper(target: listener),
            chainAssets: chainAssets
        )
        listeners.append(listener)
    }
}
