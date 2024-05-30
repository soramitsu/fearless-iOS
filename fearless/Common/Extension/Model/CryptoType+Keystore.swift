import Foundation
import SSFModels

extension CryptoType {
    var supportsSeedFromSecretKey: Bool {
        switch self {
        case .ed25519, .ecdsa:
            return true
        case .sr25519:
            return false
        }
    }
}
