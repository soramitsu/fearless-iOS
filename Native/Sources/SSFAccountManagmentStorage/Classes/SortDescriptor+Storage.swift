import Foundation

public extension NSSortDescriptor {
    static var accountsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDMetaAccount.order), ascending: true)
    }
}
