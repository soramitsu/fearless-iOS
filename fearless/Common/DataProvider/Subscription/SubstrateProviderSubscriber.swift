import Foundation
import RobinHood

@available(*, deprecated, message: "Use subsclass of StakingLocalSubscriber instead")
protocol SubstrateProviderSubscriber {
    var substrateProviderFactory: SubstrateDataProviderFactoryProtocol { get }
    var subscriptionHandler: SubstrateProviderSubscriptionHandler { get }

    func subscribeToStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem>?
}
