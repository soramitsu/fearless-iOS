import Foundation
import IrohaCrypto

enum Chain: String, Codable {
    case kusama = "Kusama"
    case polkadot = "Polkadot"
    case westend = "Westend"
}

extension Chain {
    var addressType: SNAddressType {
        switch self {
        case .polkadot:
            return .polkadotMain
        case .kusama:
            return .kusamaMain
        case .westend:
            return .genericSubstrate
        }
    }
}
