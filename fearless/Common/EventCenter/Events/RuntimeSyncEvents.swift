import Foundation
import SSFModels

struct RuntimeChainsTypesSyncCompleted: EventProtocol {
    let versioningMap: [String: Data]

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeChainsTypesSyncCompleted(event: self)
    }
}

struct RuntimeMetadataSyncCompleted: EventProtocol {
    let chainId: ChainModel.Id
    let version: RuntimeVersion
    let metadata: RuntimeMetadataItem

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeChainMetadataSyncCompleted(event: self)
    }
}
