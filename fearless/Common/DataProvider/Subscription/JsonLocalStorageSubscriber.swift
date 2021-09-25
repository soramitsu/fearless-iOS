import Foundation
import RobinHood

protocol JsonLocalStorageSubscriber where Self: AnyObject {
    var jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol { get }

    var jsonLocalSubscriptionHandler: JsonLocalSubscriptionHandler { get }

    func subscribeToCrowdloanDisplayInfo(
        for url: URL,
        chainId: ChainModel.Id
    ) -> AnySingleValueProvider<CrowdloanDisplayInfoList>?
}

extension JsonLocalStorageSubscriber {
    func subscribeToCrowdloanDisplayInfo(
        for url: URL,
        chainId: ChainModel.Id
    ) -> AnySingleValueProvider<CrowdloanDisplayInfoList>? {
        let displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList> =
            jsonLocalSubscriptionFactory.getJson(for: url)

        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            let result = changes.reduceToLastChange()
            self?.jsonLocalSubscriptionHandler.handleCrowdloanDisplayInfo(
                result: .success(result),
                url: url,
                chainId: chainId
            )
            return
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.jsonLocalSubscriptionHandler.handleCrowdloanDisplayInfo(
                result: .failure(error),
                url: url,
                chainId: chainId
            )
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        displayInfoProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return displayInfoProvider
    }
}

extension JsonLocalStorageSubscriber where Self: JsonLocalSubscriptionHandler {
    var jsonLocalSubscriptionHandler: JsonLocalSubscriptionHandler { self }
}
