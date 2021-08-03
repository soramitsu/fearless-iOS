import Foundation

struct TypeRegistryPrepared: EventProtocol {
    let version: UInt32

    func accept(visitor: EventVisitorProtocol) {
        visitor.processTypeRegistryPrepared(event: self)
    }
}
