import Foundation
import IrohaCrypto

extension SNAddressType {
    init(chain: Chain) {
        switch chain {
        case .polkadot: self = .polkadotMain
        case .kusama: self = .kusamaMain
        case .westend: self = .genericSubstrate
        case .rococo: self = .kusamaSecondary

        #if F_DEV
            case .moonbeam: self = .moonbeam
        #endif
        }
    }

    var chain: Chain {
        switch self {
        case .kusamaMain: return .kusama
        case .polkadotMain: return .polkadot
        case .kusamaSecondary: return .rococo

        #if F_DEV
            case .moonbeam: return .moonbeam
        #endif

        default:
            return .westend
        }
    }

    var precision: Int16 {
        switch self {
        case .polkadotMain: return 10
        case .genericSubstrate: return 12

        #if F_DEV
            case .moonbeam: return 10
        #endif

        default: return 12
        }
    }
}
