import Foundation

struct RuntimeBaseTypesSyncCompleted: EventProtocol {
    let fileHash: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeBaseTypesSyncCompleted(event: self)
    }
}

struct RuntimeChainTypesSyncCompleted: EventProtocol {
    let chainId: ChainModel.Id
    let fileHash: String

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeChainTypesSyncCompleted(event: self)
    }
}

struct RuntimeMetadataSyncCompleted: EventProtocol {
    let chainId: ChainModel.Id
    let version: RuntimeVersion

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeChainMetadataSyncCompleted(event: self)
    }
}
