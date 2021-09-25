import Foundation
import FearlessUtils

enum MultiassetCryptoType: UInt8 {
    case sr25519
    case ed25519
    case substrateEcdsa
    case ethereumEcdsa
}

extension MultiassetCryptoType {
    var utilsType: FearlessUtils.CryptoType {
        switch self {
        case .sr25519:
            return .sr25519
        case .ed25519:
            return .ed25519
        case .substrateEcdsa, .ethereumEcdsa:
            return .ecdsa
        }
    }
}
