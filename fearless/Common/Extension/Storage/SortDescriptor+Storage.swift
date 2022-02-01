import Foundation

extension NSSortDescriptor {
    static var accountsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDMetaAccount.order), ascending: true)
    }

    // TODO: remove
    static var connectionsByOrder: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDChain.addressPrefix), ascending: true)
    }

    static var contactsByTime: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDContactItem.updatedAt), ascending: false)
    }

    static var chainsByAddressPrefix: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDChain.addressPrefix), ascending: true)
    }
}
