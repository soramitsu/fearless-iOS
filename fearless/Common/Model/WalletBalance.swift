import Foundation

struct WalletBalance {
    let totalFiatValue: Decimal
    let enabledAssetFiatBalance: Decimal
    let dayChangePercent: Decimal
    let dayChangeValue: Decimal
    let currency: Currency
}
