import Foundation
import IrohaCrypto

@available(*, deprecated, message: "No longer used in 2.0")
enum Chain: String, Codable, CaseIterable {
    case kusama = "Kusama"
    case polkadot = "Polkadot"
    case westend = "Westend"
    case rococo = "Rococo"
    case moonbeam = "Moonbeam"
    case moonriver = "Moonriver"
    case moonbaseAlpha = "Moonbase Alpha"

    init?(rawValue: String) {
        switch rawValue {
        case Self.kusama.rawValue: self = .kusama
        case Self.polkadot.rawValue: self = .polkadot
        case Self.westend.rawValue: self = .westend
        case Self.rococo.rawValue: self = .rococo
        case Self.moonbeam.rawValue: self = .moonbeam
        case Self.moonriver.rawValue: self = .moonriver
        case Self.moonbaseAlpha.rawValue: self = .moonbaseAlpha

        #if F_DEV
            case "Polkatrain": self = .polkadot
        #endif

        default: return nil
        }
    }
}
