import Foundation
import IrohaCrypto

extension SNAddressType {
    init(chain: Chain) {
        switch chain {
        case .polkadot:
            self = .polkadotMain
        case .kusama:
            self = .kusamaMain
        case .westend:
            self = .genericSubstrate
        case .rococo:
            self = .kusamaSecondary
        case .moonriver:
            self = .moonriver
        case .moonBaseAlpha:
            self = .moonbaseAlpha
        case .karura:
            self = .karura
        case .centrifuge:
            self = .centrifuge
        case .chainX:
            self = .chainX
        case .darwinia:
            self = .darwinia
        case .edgeware:
            self = .edgeware
        case .kulupu:
            self = .kulupu
        case .plasm:
            self = .plasm
        case .subsocial:
            self = .subsocial
        case .sora:
            self = .sora
        case .statemine:
            self = .statemine
        }
    }

    var chain: Chain {
        switch self {
        case .kusamaMain:
            return .kusama
        case .polkadotMain:
            return .polkadot
        case .kusamaSecondary:
            return .rococo
        case .karura:
            return .karura
        case .moonriver:
            return .moonriver
        case .moonbaseAlpha:
            return .moonBaseAlpha
        case .genericSubstrate:
            return .westend
        case .polkadotSecondary:
            return .polkadot
        case .centrifuge:
            return .centrifuge
        case .chainX:
            return .chainX
        case .darwinia:
            return .darwinia
        case .edgeware:
            return .edgeware
        case .kulupu:
            return .kulupu
        case .plasm:
            return .plasm
        case .sora:
            return .sora
        case .subsocial:
            return .subsocial
        case .statemine:
            return .statemine
        }
    }

    var precision: Int16 {
        switch self {
        case .polkadotMain:
            return 10
        case .genericSubstrate:
            return 12
        default:
            return 12
        }
    }
}
