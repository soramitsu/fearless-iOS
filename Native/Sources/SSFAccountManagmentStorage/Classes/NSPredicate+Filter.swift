import Foundation
import IrohaCrypto
import SSFModels

public extension NSPredicate {
    static func selectedMetaAccount() -> NSPredicate {
        NSPredicate(format: "%K == true", #keyPath(CDMetaAccount.isSelected))
    }
}
