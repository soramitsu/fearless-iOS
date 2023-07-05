import Foundation
import SSFModels

struct WalletRemoteSubscriptionWasUpdatedEvent: EventProtocol {
    let chainModel: ChainModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRemoteSubscriptionWasUpdated(event: self)
    }
}
