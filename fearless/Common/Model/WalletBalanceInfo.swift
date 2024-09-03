import Foundation
import SSFModels

struct WalletBalanceInfo: Equatable {
    let totalFiatValue: Decimal
    let enabledAssetFiatBalance: Decimal
    let dayChangePercent: Decimal
    let dayChangeValue: Decimal
    let currency: Currency

    let prices: [PriceData]
    let accountInfos: [ChainAssetKey: AccountInfo?]
}
