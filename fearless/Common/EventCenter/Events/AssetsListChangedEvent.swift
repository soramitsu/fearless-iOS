import Foundation

struct AssetsListChangedEvent: EventProtocol {
    let account: MetaAccountModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processAssetsListChanged(event: self)
    }
}
