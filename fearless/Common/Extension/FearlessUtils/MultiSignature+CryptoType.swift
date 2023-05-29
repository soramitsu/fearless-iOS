import Foundation
import SSFUtils

extension MultiSignature {
    static func signature(from cryptoType: CryptoType, data: Data) -> MultiSignature? {
        switch cryptoType {
        case .sr25519:
            return MultiSignature.sr25519(data: data)
        case .ed25519:
            return MultiSignature.ed25519(data: data)
        case .ecdsa:
            return MultiSignature.ecdsa(data: data)
        }
    }
}
