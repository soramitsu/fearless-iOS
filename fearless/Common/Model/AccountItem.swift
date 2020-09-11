import Foundation

enum CryptoType: UInt8, Codable, CaseIterable {
    case sr25519
    case ed25519
    case ecdsa
}

struct AccountItem: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case address
        case cryptoType
        case username
        case publicKeyData
    }

    let address: String
    let cryptoType: CryptoType
    let username: String
    let publicKeyData: Data
}

extension AccountItem {
    init(managedItem: ManagedAccountItem) {
        self = AccountItem(address: managedItem.address,
                           cryptoType: managedItem.cryptoType,
                           username: managedItem.username,
                           publicKeyData: managedItem.publicKeyData)
    }

    func replacingUsername(_ newUsername: String) -> AccountItem {
        AccountItem(address: address,
                    cryptoType: cryptoType,
                    username: newUsername,
                    publicKeyData: publicKeyData)
    }
}
