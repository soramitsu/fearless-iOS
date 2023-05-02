import Foundation

struct KYCShouldRestart: EventProtocol {
    let data: SCKYCUserDataModel?

    func accept(visitor: EventVisitorProtocol) {
        visitor.processKYCShouldRestart(data: data)
    }
}
