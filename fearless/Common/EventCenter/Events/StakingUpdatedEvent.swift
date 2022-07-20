import Foundation

struct StakingUpdatedEvent: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processStakingUpdatedEvent()
    }
}
