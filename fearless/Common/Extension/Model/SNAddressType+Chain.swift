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
        }
    }

    var chain: Chain {
        switch self {
        case .kusamaMain:
            return .kusama
        case .polkadotMain:
            return .polkadot
        default:
            return .westend
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
