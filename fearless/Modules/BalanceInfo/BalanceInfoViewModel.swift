import Foundation

struct BalanceInfoViewModel {
    let dayChangeAttributedString: NSAttributedString?
    let balanceString: String
    let infoButtonEnabled: Bool
    /// "Showing {network} · {amount}" under the wallet-wide total while the portfolio
    /// shows only some networks.
    var filteredPartString: String?
}
