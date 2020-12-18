import Foundation

struct WalletNewTransactionInserted: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processNewTransaction(event: self)
    }
}
