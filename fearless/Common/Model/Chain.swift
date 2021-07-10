import Foundation
import IrohaCrypto

enum Chain: String, Codable, CaseIterable {
    case kusama = "Kusama"
    case polkadot = "Polkadot"
    case westend = "Westend"
    case rococo = "Rococo"
    case karura = "Karura"
    case moonriver = "Moonriver"
    case edgeware = "Edgeware"
    case plasm = "Plasm"
    case sora = "Sora"
    case darwinia = "Darwinia"
    case kulupu = "Kulupu"
    case chainX = "ChainX"
    case centrifuge = "Centrifuge"
    case subsocial = "Subsocial"
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
        case .rococo:
            return .kusamaSecondary
        case .karura:
            return .karura
        case .moonriver:
            return .moonriver
        case .edgeware:
            return .edgeware
        case .plasm:
            return .plasm
        case .sora:
            return .sora
        case .darwinia:
            return .darwinia
        case .kulupu:
            return .kulupu
        case .chainX:
            return .chainX
        case .centrifuge:
            return .centrifuge
        case .subsocial:
            return .subsocial
        }
    }
}
