import Foundation
import SSFUtils

struct ChainReconnectingEvent: EventProtocol {
    let chain: ChainModel
    let state: WebSocketEngine.State

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainReconnecting(event: self)
    }
}
