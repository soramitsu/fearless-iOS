import Foundation
import SSFModels

struct SelectedCurrencyChangedEvent: EventProtocol {
    let account: MetaAccountModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSelectedCurrencyChanged(event: self)
    }
}
