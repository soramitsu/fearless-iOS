import Foundation
import SSFModels

struct RuntimeSnapshotReady: EventProtocol {
    let chainModel: ChainModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeSnapshorReady(event: RuntimeSnapshotReady(chainModel: chainModel))
    }
}
