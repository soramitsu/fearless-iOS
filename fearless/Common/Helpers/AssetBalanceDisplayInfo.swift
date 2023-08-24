import Foundation
import SSFModels
import SoraFoundation

extension AssetBalanceDisplayInfo {
    static func forCurrency(_ currency: Currency) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 2,
            assetPrecision: 2,
            symbol: currency.symbol,
            symbolValueSeparator: "",
            symbolPosition: .prefix,
            icon: nil
        )
    }

    static func percent() -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 2,
            assetPrecision: 2,
            symbol: "%",
            symbolValueSeparator: "",
            symbolPosition: .suffix,
            icon: nil
        )
    }

    static func fromCrowdloan(info: CrowdloanDisplayInfo) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: 5,
            symbol: info.token,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: URL(string: info.icon)
        )
    }
}
