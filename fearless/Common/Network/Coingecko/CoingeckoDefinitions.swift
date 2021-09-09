import Foundation
import IrohaCrypto

struct CoingeckoAPI {
    static let price = "simple/price"
}

extension WalletAssetId {
    var coingeckoTokenId: String? {
        switch self {
        case .dot:
            return "polkadot"
        case .kusama:
            return "kusama"
        default:
            return nil
        }
    }
}
