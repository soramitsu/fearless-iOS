import Foundation
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif

extension NSSortDescriptor {
    static var chainsByAddressPrefix: NSSortDescriptor {
        // Use literal to avoid module-qualified #keyPath limitation
        NSSortDescriptor(key: "addressPrefix", ascending: true)
    }
}
