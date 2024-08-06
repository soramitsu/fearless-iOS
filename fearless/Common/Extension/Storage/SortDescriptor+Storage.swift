import Foundation
import SSFAccountManagmentStorage

extension NSSortDescriptor {
    static var chainsByAddressPrefix: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(CDChain.addressPrefix), ascending: true)
    }
}
