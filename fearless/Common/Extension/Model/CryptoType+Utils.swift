import Foundation
import SSFUtils

extension CryptoType {
    init(_ utilsType: SSFUtils.CryptoType) {
        switch utilsType {
        case .sr25519:
            self = .sr25519
        case .ed25519:
            self = .ed25519
        case .ecdsa:
            self = .ecdsa
        }
    }

    var utilsType: SSFUtils.CryptoType {
        switch self {
        case .sr25519:
            return .sr25519
        case .ed25519:
            return .ed25519
        case .ecdsa:
            return .ecdsa
        }
    }
}
