import Foundation
import FearlessUtils

struct ChainReconnectingEvent: EventProtocol {
    let chain: ChainModel
    let state: WebSocketEngine.State

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainReconnecting(event: self)
    }
}
