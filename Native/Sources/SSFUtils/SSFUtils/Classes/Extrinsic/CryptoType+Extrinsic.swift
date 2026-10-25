import Foundation
import SSFModels

extension CryptoType {
    public init?(onChainType: UInt8) {
        switch onChainType {
        case 0:
            self = .sr25519
        case 1:
            self = .ed25519
        case 2:
            self = .ecdsa
        default:
            return nil
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "ecdsa":
            self = .ecdsa
        case "sr25519":
            self = .sr25519
        case "ed25519":
            self = .ed25519
        case "ethereum":
            self = .ecdsa
        default:
            return nil
        }
    }

    var onChainType: UInt8 {
        switch self {
        case .sr25519:
            return 1
        case .ed25519:
            return 0
        case .ecdsa:
            return 2
        }
    }

    var signatureLength: Int {
        switch self {
        case .sr25519:
            return 64
        case .ed25519:
            return 64
        case .ecdsa:
            return 65
        }
    }
}
