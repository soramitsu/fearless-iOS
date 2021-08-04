import Foundation

struct ConnectionPoolState {
    let chainId: ChainModel.Id
    let state: WebSocketEngine.State
}
