import Foundation

extension NSSortDescriptor {
    static var accountsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDAccountItem.order), ascending: true)
    }

    static var connectionsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDConnectionItem.order), ascending: true)
    }

    static var contactsByTime: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDContactItem.updatedAt), ascending: false)
    }
}
