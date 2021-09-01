import Foundation
import IrohaCrypto

struct SubscanApi {
    static let price = "api/open/price"
    static let transfers = "api/scan/transfers"
    static let rewardsAndSlashes = "api/scan/account/reward_slash"
    static let extrinsics = "api/scan/extrinsics"
}

extension WalletAssetId {
    var subscanUrl: URL? {
        switch self {
        case .dot:
            return URL(string: "https://polkadot.api.subscan.io/")
        case .kusama:
            return URL(string: "https://kusama.api.subscan.io/")
        case .westend:
            return URL(string: "https://westend.api.subscan.io/")
        default:
            return nil
        }
    }

    var subqueryHistoryUrl: URL? {
        switch self {
        case .dot:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet")
        case .kusama:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet-ksm")
        case .westend:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet-westend")
        default:
            return nil
        }
    }

    var hasPrice: Bool {
        switch self {
        case .dot, .kusama:
            return true
        case .usd, .westend, .roc:
            return false
        }
    }
}
