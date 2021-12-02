import Foundation
import SoraFoundation

struct AssetBalanceDisplayInfo {
    enum Constants {
        static let usdDisplayPrecision: UInt16 = 2
        static let usdAssetPrecision: Int16 = 2
        static let percentDisplayPrecision: UInt16 = 2
        static let percentAssetPrecision: Int16 = 2
        static let crowdloanDisplayPrecision: UInt16 = 5
        static let crowdloanAssetPrecision: Int16 = 5
        static let assetDisplayPrecision: UInt16 = 5
    }

    let displayPrecision: UInt16
    let assetPrecision: Int16
    let symbol: String
    let symbolValueSeparator: String
    let symbolPosition: TokenSymbolPosition
    let icon: URL?
}

extension AssetBalanceDisplayInfo {
    static func usd() -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: Constants.usdDisplayPrecision,
            assetPrecision: Constants.usdAssetPrecision,
            symbol: "$",
            symbolValueSeparator: "",
            symbolPosition: .prefix,
            icon: nil
        )
    }

    static func percent() -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: Constants.percentDisplayPrecision,
            assetPrecision: Constants.percentAssetPrecision,
            symbol: "%",
            symbolValueSeparator: "",
            symbolPosition: .suffix,
            icon: nil
        )
    }

    static func fromCrowdloan(info: CrowdloanDisplayInfo) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: Constants.crowdloanDisplayPrecision,
            assetPrecision: Constants.crowdloanAssetPrecision,
            symbol: info.token,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: URL(string: info.icon)
        )
    }
}

extension AssetModel {
    var displayInfo: AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: AssetBalanceDisplayInfo.Constants.assetDisplayPrecision,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon
        )
    }

    func displayInfo(with chainIcon: URL) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: AssetBalanceDisplayInfo.Constants.assetDisplayPrecision,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon ?? chainIcon
        )
    }
}
