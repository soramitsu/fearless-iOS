import Foundation

struct MetaAccountModelChangedEvent: EventProtocol {
    let account: MetaAccountModel

    func accept(visitor: EventVisitorProtocol) {
        visitor.processMetaAccountChanged(event: self)
    }
}

struct RuntimesBuildedCount: EventProtocol {
    let count: Int

    func accept(visitor: EventVisitorProtocol) {
        visitor.processRuntimeBuilded(count: self)
    }
}
