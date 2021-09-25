import Foundation
import SoraFoundation

struct AssetBalanceDisplayInfo {
    let preferrableDisplayPrecision: UInt16
    let assetPrecision: Int16
    let symbol: String
    let symbolValueSeparator: String
    let symbolPosition: TokenSymbolPosition
    let icon: URL?
}

extension AssetBalanceDisplayInfo {
    static func usd() -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            preferrableDisplayPrecision: 2,
            assetPrecision: 2,
            symbol: "$",
            symbolValueSeparator: "",
            symbolPosition: .prefix,
            icon: nil
        )
    }

    static func fromCrowdloan(info: CrowdloanDisplayInfo) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            preferrableDisplayPrecision: 5,
            assetPrecision: 5,
            symbol: info.token,
            symbolValueSeparator: " ",
            symbolPosition: .prefix,
            icon: URL(string: info.icon)
        )
    }
}

extension AssetModel {
    var displayInfo: AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            preferrableDisplayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon
        )
    }

    func displayInfo(with chainIcon: URL) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            preferrableDisplayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon ?? chainIcon
        )
    }
}
