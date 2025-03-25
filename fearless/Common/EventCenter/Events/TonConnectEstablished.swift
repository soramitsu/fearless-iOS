import Foundation

struct TonConnectEstablished: EventProtocol {
    func accept(visitor: any EventVisitorProtocol) {
        visitor.processTonConnectEstablished()
    }
}
