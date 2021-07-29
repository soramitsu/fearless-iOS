import Foundation

extension WalletAssetId {
    var subqueryUrl: URL? {
        switch self {
        case .dot:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet__ZWYxc")
        case .kusama:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet-ksm__ZWYxc")
        case .westend:
            return URL(string: "https://api.subquery.network/sq/ef1rspb/fearless-wallet-westend__ZWYxc")
        default:
            return nil
        }
    }
}
