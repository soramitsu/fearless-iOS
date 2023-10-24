import Foundation

struct SelectedAccountChanged: EventProtocol {
    var account: MetaAccountModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedAccountChanged(event: self)
    }
}
