import Foundation
import SSFUtils
import SSFModels

struct ChainReconnectingEvent: EventProtocol {
    let chain: ChainModel
    let state: WebSocketEngine.State

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainReconnecting(event: self)
    }
}
