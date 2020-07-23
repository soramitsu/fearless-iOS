import Foundation

enum CryptoType: UInt8, Codable {
    case sr25519
    case ed25519
    case ecdsa
}

struct AccountItem: Codable {
    let address: String
    let cryptoType: CryptoType
}
