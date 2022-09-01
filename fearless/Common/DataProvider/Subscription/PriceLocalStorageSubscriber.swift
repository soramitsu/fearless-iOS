import Foundation
import RobinHood

protocol PriceLocalStorageSubscriber where Self: AnyObject {
    var priceLocalSubscriptionFactory: PriceProviderFactoryProtocol { get }

    var priceLocalSubscriptionHandler: PriceLocalSubscriptionHandler { get }

    func subscribeToPrice(for priceId: AssetModel.PriceId) -> AnySingleValueProvider<PriceData>
    func subscribeToPrices(for pricesIds: [AssetModel.PriceId]) -> AnySingleValueProvider<[PriceData]>
}

extension PriceLocalStorageSubscriber {
    func subscribeToPrice(for priceId: AssetModel.PriceId) -> AnySingleValueProvider<PriceData> {
        let priceProvider = priceLocalSubscriptionFactory.getPriceProvider(for: priceId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            guard let finalValue = changes.reduceToLastChange() else { return }
            self?.priceLocalSubscriptionHandler.handlePrice(result: .success(finalValue), priceId: priceId)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.priceLocalSubscriptionHandler.handlePrice(result: .failure(error), priceId: priceId)
            return
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

    func subscribeToPrices(for pricesIds: [AssetModel.PriceId]) -> AnySingleValueProvider<[PriceData]> {
        let priceProvider = priceLocalSubscriptionFactory.getPricesProvider(for: pricesIds)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[PriceData]>]) in
            guard let finalValue = changes.reduceToLastChange() else { return }
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
