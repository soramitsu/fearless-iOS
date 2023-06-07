import Foundation
import RobinHood
import SSFModels
import SoraFoundation

extension AssetModel: Identifiable {
    public var identifier: String { id }

    public var displayInfo: AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon
        )
    }

    public func displayInfo(with chainIcon: URL?) -> AssetBalanceDisplayInfo {
        AssetBalanceDisplayInfo(
            displayPrecision: 5,
            assetPrecision: Int16(bitPattern: precision),
            symbol: symbol,
            symbolValueSeparator: " ",
            symbolPosition: .suffix,
            icon: icon ?? chainIcon
        )
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
