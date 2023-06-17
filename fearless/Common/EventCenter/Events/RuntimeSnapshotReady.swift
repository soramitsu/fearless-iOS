import Foundation

struct RuntimeSnapshotReady: EventProtocol {
    let chainModel: ChainModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeSnapshorReady()
    }
}
