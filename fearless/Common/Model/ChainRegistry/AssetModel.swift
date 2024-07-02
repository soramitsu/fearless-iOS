import Foundation
import RobinHood
import SSFModels
import SoraFoundation

public extension AssetModel {
    var displayInfo: AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbolUppercased,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon
        )
    }

    func displayInfo(with chainIcon: URL?) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbolUppercased,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon ?? chainIcon
        )
    }

    func normalizedSymbol() -> String {
        guard symbol.hasPrefix("xc") else {
            return symbol
        }

        return String(symbol.dropFirst(2))
    }
}

public struct AssetBalanceDisplayInfo: Equatable {
    public let displayPrecision: UInt16
    public let assetPrecision: Int16
    public let symbol: String
    public let symbolValueSeparator: String
    public let symbolPosition: TokenSymbolPosition
    public let icon: URL?

    public init(
        displayPrecision: UInt16,
        assetPrecision: Int16,
        symbol: String,
        symbolValueSeparator: String,
        symbolPosition: TokenSymbolPosition,
        icon: URL?
    ) {
        self.displayPrecision = displayPrecision
        self.assetPrecision = assetPrecision
        self.symbol = symbol
        self.symbolValueSeparator = symbolValueSeparator
        self.symbolPosition = symbolPosition
        self.icon = icon
    }
}
