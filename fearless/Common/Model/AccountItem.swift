import Foundation

enum CryptoType: UInt8, Codable, CaseIterable {
    case sr25519
    case ed25519
    case ecdsa
}

@available(*, deprecated, message: "Use MetaAccount instead")
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
