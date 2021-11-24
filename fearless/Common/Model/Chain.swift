import Foundation
import IrohaCrypto

@available(*, deprecated, message: "No longer used in 2.0")
enum Chain: String, Codable, CaseIterable {
    case kusama = "Kusama"
    case polkadot = "Polkadot"
    case westend = "Westend"
    case rococo = "Rococo"

    init?(rawValue: String) {
        switch rawValue {
        case Self.kusama.rawValue: self = .kusama
        case Self.polkadot.rawValue: self = .polkadot
        case Self.westend.rawValue: self = .westend
        case Self.rococo.rawValue: self = .rococo

        #if F_DEV
            case "Polkatrain": self = .polkadot
        #endif

        default: return nil
        }
    }
}

extension Chain {
    var addressType: SNAddressType {
        switch self {
        case .polkadot: return .polkadotMain
        case .kusama: return .kusamaMain
        case .westend: return .genericSubstrate
        case .rococo: return .kusamaSecondary
        }
    }
}
