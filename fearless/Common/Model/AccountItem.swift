import Foundation

enum CryptoType: UInt8, Codable, CaseIterable {
    case sr25519
    case ed25519
    case ecdsa

    var stringValue: String {
        switch self {
        case .sr25519:
            return "sr25519"
        case .ed25519:
            return "ed25519"
        case .ecdsa:
            return "ecdsa"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "sr25519":
            self = .sr25519
        case "ed25519":
            self = .ed25519
        case "ecdsa":
            self = .ecdsa
        default:
            return nil
        }
    }
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
