import Foundation
import IrohaCrypto

extension NSPredicate {
    static func filterBy(networkType: SNAddressType) -> NSPredicate {
        let rawValue = Int16(networkType.rawValue)
        return NSPredicate(format: "%K == %d", #keyPath(CDAccountItem.networkType), rawValue)
    }
}
