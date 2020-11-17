import Foundation

struct SelectedUsernameChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedUsernameChanged(event: self)
    }
}
