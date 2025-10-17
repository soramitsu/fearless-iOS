import Foundation
import SSFAssetManagmentStorage

extension NSSortDescriptor {
    static var chainsByAddressPrefix: NSSortDescriptor {
        NSSortDescriptor(key: #keyPath(SSFAssetManagmentStorage.CDChain.addressPrefix), ascending: true)
    }
}
