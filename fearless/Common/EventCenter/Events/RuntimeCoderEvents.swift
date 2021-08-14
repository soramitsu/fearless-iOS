import Foundation

struct RuntimeCoderCreated: EventProtocol {
    let chainId: ChainModel.Id

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeCoderReady(event: self)
    }
}

struct RuntimeCoderCreationFailed: EventProtocol {
    let chainId: ChainModel.Id
    let error: Error

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeCoderCreationFailed(event: self)
    }
}
