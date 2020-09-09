import Foundation
import IrohaCrypto

struct ManagedAccountItem: Equatable {
    let address: String
    let cryptoType: CryptoType
    let networkType: SNAddressType
    let username: String
    let publicKeyData: Data
    let order: Int16
}

extension ManagedAccountItem {
    func replacingOrder(_ newOrder: Int16) -> ManagedAccountItem {
        ManagedAccountItem(address: address,
                           cryptoType: cryptoType,
                           networkType: networkType,
                           username: username,
                           publicKeyData: publicKeyData,
                           order: newOrder)
    }

    func replacingUsername(_ newUsername: String) -> ManagedAccountItem {
        ManagedAccountItem(address: address,
                           cryptoType: cryptoType,
                           networkType: networkType,
                           username: newUsername,
                           publicKeyData: publicKeyData,
                           order: order)
    }
}
