import Foundation

struct WalletBalanceChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processBalanceChanged(event: self)
    }
}
