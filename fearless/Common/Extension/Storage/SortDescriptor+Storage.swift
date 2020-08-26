import Foundation

extension NSSortDescriptor {
    static var accountsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDAccountItem.order), ascending: true)
    }
}
