import Foundation
import RobinHood

protocol PriceLocalStorageSubscriber where Self: AnyObject {
    var priceLocalSubscriptionFactory: PriceProviderFactoryProtocol { get }

    var priceLocalSubscriptionHandler: PriceLocalSubscriptionHandler { get }

    func subscribeToPrice(for priceId: AssetModel.PriceId) -> AnySingleValueProvider<PriceData>?
}

extension PriceLocalStorageSubscriber {
    func subscribeToPrice(for priceId: AssetModel.PriceId) -> AnySingleValueProvider<PriceData>? {
        let priceProvider = priceLocalSubscriptionFactory.getPriceProvider(for: priceId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            let finalValue = changes.reduceToLastChange()
            self?.priceLocalSubscriptionHandler.handlePrice(result: .success(finalValue), priceId: priceId)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.priceLocalSubscriptionHandler.handlePrice(result: .failure(error), priceId: priceId)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
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
