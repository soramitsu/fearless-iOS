import Foundation
import SSFModels

struct SelectedAccountChanged: EventProtocol {
    var account: MetaAccountModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedAccountChanged(event: self)
    }
}
