import Foundation
import RobinHood

extension SubstrateProviderSubscriber where Self: AnyObject {
    func subscribeToStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem>? {
        let provider = substrateProviderFactory.createStashItemProvider(for: address)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.subscriptionHandler.handleStashItem(result: .success(stashItem))
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.subscriptionHandler.handleStashItem(result: .failure(error))
            return
        }

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: changesClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions.substrateSource()
        )

        return provider
    }
}

extension SubstrateProviderSubscriber where Self: SubstrateProviderSubscriptionHandler {
    var subscriptionHandler: SubstrateProviderSubscriptionHandler { self }
}
