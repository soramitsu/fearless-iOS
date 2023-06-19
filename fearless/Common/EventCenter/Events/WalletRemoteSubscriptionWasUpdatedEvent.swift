import Foundation

struct WalletRemoteSubscriptionWasUpdatedEvent: EventProtocol {
    let chainAsset: ChainAsset

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRemoteSubscriptionWasUpdated(event: self)
    }
}
