import Foundation
import IrohaCrypto

extension WalletAssetId {
    var chain: Chain? {
        switch self {
        case .dot:
            return .polkadot
        case .kusama:
            return .kusama
        case .westend:
            return .westend
        case .roc:
            return .rococo
        case .usd:
            return nil
        }
    }
}
