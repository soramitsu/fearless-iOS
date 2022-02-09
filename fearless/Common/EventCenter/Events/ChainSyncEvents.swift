import Foundation

struct ChainSyncDidStart: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainSyncDidStart(event: self)
    }
}

struct ChainSyncDidComplete: EventProtocol {
    let newOrUpdatedChains: [ChainModel]
    let removedChains: [ChainModel]

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainSyncDidComplete(event: self)
    }
}

struct ChainSyncDidFail: EventProtocol {
    let error: Error

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainSyncDidFail(event: self)
    }
}
