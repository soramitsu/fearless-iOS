import Foundation

struct EraStakersInfoChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processEraStakersInfoChanged(event: self)
    }
}
