import Foundation

struct KYCShouldRestart: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processKYCShouldRestart()
    }
}
