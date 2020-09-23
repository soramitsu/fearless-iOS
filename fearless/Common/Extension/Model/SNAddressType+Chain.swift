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
}
