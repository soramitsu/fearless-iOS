import Foundation
import SSFModels

extension ChainAccountModel {
    func toAddress(addressPrefix: UInt16) -> AccountAddress? {
        try? accountId.toAddress(using: .substrate(addressPrefix))
    }
}
