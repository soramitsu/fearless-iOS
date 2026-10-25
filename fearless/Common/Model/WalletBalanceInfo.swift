import Foundation
import SSFModels

struct WalletBalanceInfo {
    /// Every valued holding, hidden ones included. Wallet management, backup and the
    /// wallet cards show it, labelled "incl. hidden" when hidden assets add to it, so a
    /// wallet whose funds are all hidden never looks empty before a delete (critique D-12).
    let totalFiatValue: Decimal
    /// The portfolio total: holdings neither hidden, nor on a testnet, nor without a
    /// trusted price (root `docs/portfolio-contract.md` §3).
    let enabledAssetFiatBalance: Decimal
    /// The 24h change of `enabledAssetFiatBalance`.
    let dayChangePercent: Decimal
    let dayChangeValue: Decimal
    /// The 24h change of `totalFiatValue`.
    let totalDayChangePercent: Decimal
    let totalDayChangeValue: Decimal
    let currency: Currency

    let prices: [PriceData]
    let accountInfos: [ChainAssetKey: AccountInfo?]
    /// What `enabledAssetFiatBalance` leaves out.
    let exclusions: PortfolioExclusions
    /// The part of the wallet-wide portfolio total on the networks the portfolio filter
    /// shows; nil when it shows every network.
    var filteredPart: WalletBalanceFilteredPart?

    /// "incl. hidden" for the wallet cards when hidden assets add value to `totalFiatValue`.
    var allHoldingsCaption: String? {
        guard exclusions.hiddenFiat > 0 else {
            return nil
        }

        return NSLocalizedString("portfolio.balance.incl_hidden", value: "incl. hidden", comment: "")
    }
}

struct WalletBalanceFilteredPart {
    let filter: NetworkManagmentFilter
    /// The network's name for a single-network filter.
    let networkName: String?
    let fiatBalance: Decimal
}
