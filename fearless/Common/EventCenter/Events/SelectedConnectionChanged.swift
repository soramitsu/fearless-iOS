import Foundation

struct SelectedConnectionChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedConnectionChanged(event: self)
    }
}
