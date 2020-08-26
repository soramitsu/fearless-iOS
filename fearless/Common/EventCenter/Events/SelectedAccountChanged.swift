import Foundation

struct SelectedAccountChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedAccountChanged(event: self)
    }
}
