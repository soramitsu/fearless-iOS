import Foundation

struct UserInactiveEvent: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processUserInactive(event: self)
    }
}
