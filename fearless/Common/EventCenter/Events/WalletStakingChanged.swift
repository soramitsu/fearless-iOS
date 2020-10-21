import Foundation

struct WalletStakingInfoChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processStakingChanged(event: self)
    }
}
