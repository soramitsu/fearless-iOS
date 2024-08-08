import Foundation
import SSFModels

struct MetaAccountModelChangedEvent: EventProtocol {
    let account: MetaAccountModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processMetaAccountChanged(event: self)
    }
}
