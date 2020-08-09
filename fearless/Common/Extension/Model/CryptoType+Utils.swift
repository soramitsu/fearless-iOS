import Foundation
import FearlessUtils

extension CryptoType {
    init(_ utilsType: FearlessUtils.CryptoType) {
        switch utilsType {
        case .sr25519:
            self = .sr25519
        case .ed25519:
            self = .ed25519
        case .ecdsa:
            self = .ecdsa
        }
    }
}
