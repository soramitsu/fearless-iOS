import Foundation

struct WalletBalanceInfo {
    let totalFiatValue: Decimal
    let enabledAssetFiatBalance: Decimal
    let dayChangePercent: Decimal
    let dayChangeValue: Decimal
    let currency: Currency

    let prices: [PriceData]
    let accountInfos: [ChainAssetKey: AccountInfo?]
}
