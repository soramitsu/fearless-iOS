import Foundation
import RobinHood
import SSFModels

protocol PriceLocalStorageSubscriber where Self: AnyObject {
    var priceLocalSubscriptionFactory: PriceProviderFactoryProtocol { get }
    var priceLocalSubscriptionHandler: PriceLocalSubscriptionHandler { get }

    func subscribeToPrice(for chainAsset: ChainAsset) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrice(for chainAsset: ChainAsset, currencies: [Currency]?) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrices(for chainAssets: [ChainAsset]) -> AnySingleValueProvider<[PriceData]>
    func subscribeToPrices(for chainAssets: [ChainAsset], currencies: [Currency]?) -> AnySingleValueProvider<[PriceData]>
}

extension PriceLocalStorageSubscriber {
    func subscribeToPrice(for chainAsset: ChainAsset) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrice(for: chainAsset, currencies: nil)
    }

    func subscribeToPrices(for chainAssets: [ChainAsset]) -> AnySingleValueProvider<[PriceData]> {
        subscribeToPrices(for: chainAssets, currencies: nil)
    }

    func subscribeToPrice(for chainAsset: ChainAsset, currencies: [Currency]?) -> AnySingleValueProvider<[PriceData]> {
        let priceProvider = priceLocalSubscriptionFactory.getPricesProvider(currencies: currencies)

        let updateClosure = { [weak self, chainAsset] (changes: [DataProviderChange<[PriceData]>]) in
            guard let finalValue = changes.reduceToLastChange()?.first(where: { $0.priceId == chainAsset.asset.priceId }) else { return }
            self?.priceLocalSubscriptionHandler.handlePrice(result: .success(finalValue), chainAsset: chainAsset)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.priceLocalSubscriptionHandler.handlePrice(result: .failure(error), chainAsset: chainAsset)
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

    func subscribeToPrices(for chainAssets: [ChainAsset], currencies: [Currency]?) -> AnySingleValueProvider<[PriceData]> {
        let priceProvider = priceLocalSubscriptionFactory.getPricesProvider(currencies: currencies)

        let updateClosure = { [weak self, chainAssets] (changes: [DataProviderChange<[PriceData]>]) in
            guard let finalValue = changes.reduceToLastChange()?.filter({ price in chainAssets.contains(where: { $0.asset.priceId == price.priceId }) == true }) else { return }
            self?.priceLocalSubscriptionHandler.handlePrices(result: .success(finalValue))
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.priceLocalSubscriptionHandler.handlePrices(result: .failure(error))
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
}

extension PriceLocalStorageSubscriber where Self: PriceLocalSubscriptionHandler {
    var priceLocalSubscriptionHandler: PriceLocalSubscriptionHandler { self }
}
