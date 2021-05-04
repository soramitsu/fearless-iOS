import Foundation
import RobinHood

protocol SubstrateProviderSubscriber {
    var substrateProviderFactory: SubstrateDataProviderFactoryProtocol { get }
    var subscriptionHandler: SubstrateProviderSubscriptionHandler { get }

    func subscribeToStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem>?
}
