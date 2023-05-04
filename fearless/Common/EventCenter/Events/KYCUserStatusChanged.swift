import Foundation

struct KYCUserStatusChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processKYCUserStatusChanged()
    }
}
