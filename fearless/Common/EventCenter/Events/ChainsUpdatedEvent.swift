import Foundation
import SSFModels

struct ChainsUpdatedEvent: EventProtocol {
    let updatedChains: [ChainModel]

    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainsUpdated(event: self)
    }
}
