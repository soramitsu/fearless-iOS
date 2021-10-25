import Foundation
import IrohaCrypto

enum Chain: String, Codable, CaseIterable {
    case kusama = "Kusama"
    case polkadot = "Polkadot"
    case westend = "Westend"
    case rococo = "Rococo"

    #if F_DEV
        case moonbeam = "Polkatrain"
    #endif
}

extension Chain {
    var addressType: SNAddressType {
        switch self {
        case .polkadot: return .polkadotMain
        case .kusama: return .kusamaMain
        case .westend: return .genericSubstrate
        case .rococo: return .kusamaSecondary

        #if F_DEV
            case .moonbeam: return .moonbeam
        #endif
        }
    }
}
