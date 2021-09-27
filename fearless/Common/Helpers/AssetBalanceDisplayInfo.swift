import Foundation
import SoraFoundation

struct AssetBalanceDisplayInfo {
    let displayPrecision: UInt16
    let assetPrecision: Int16
    let symbol: String
    let symbolValueSeparator: String
    let symbolPosition: TokenSymbolPosition
}

extension AssetBalanceDisplayInfo {
    static func usd() -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 2,
            assetPrecision: 2,
            symbol: "$",
            symbolValueSeparator: "",
            symbolPosition: .prefix
        )
    }
}

extension AssetModel {
    var displayInfo: AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix
        )
    }
}
