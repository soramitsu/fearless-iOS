import Foundation
import IrohaCrypto

extension SNAddressType {
    var chain: Chain {
        switch self {
        case .kusamaMain: return .kusama
        case .polkadotMain: return .polkadot
        case .kusamaSecondary: return .rococo

        default:
            return .westend
        }
    }

    var precision: Int16 {
        switch self {
        case .polkadotMain: return 10
        case .genericSubstrate: return 12
        default: return 12
        }
    }
}
