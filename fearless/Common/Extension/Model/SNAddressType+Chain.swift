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
