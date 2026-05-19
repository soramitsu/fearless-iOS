import Foundation
import SSFModels

extension ChainAccountModel {
    func toAddress(addressPrefix: UInt16) -> AccountAddress? {
        let format: ChainFormat = ethereumBased ? .ethereum : .substrate(addressPrefix)
        return try? accountId.toAddress(using: format)
    }
}
