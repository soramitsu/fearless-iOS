import Foundation
import IrohaCrypto
import SSFModels

@available(*, deprecated, message: "Use MetaAccount instead")
struct ManagedAccountItem: Equatable {
    let address: String
    let cryptoType: CryptoType
    let networkType: SNAddressType
    let username: String
    let publicKeyData: Data
    let order: Int16
}
