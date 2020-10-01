import Foundation
import IrohaCrypto

struct SubscanApi {
    static let price = "api/open/price"
}

extension WalletAssetId {
    var subscanUrl: URL? {
        switch self {
        case .dot:
            return URL(string: "https://polkadot.subscan.io/")
        case .kusama:
            return URL(string: "https://kusama.subscan.io/")
        default:
            return nil
        }
    }
}
