import Foundation
import SoraFoundation

enum LiquiditySourceType: String, Codable {
    case smart
    case xyk = "XYKPool"
    case tbc = "MulticollateralBondingCurvePool"

    var name: String {
        switch self {
        case .smart:
            return "Smart"
        case .xyk:
            return "xyk"
        case .tbc:
            return "tbc"
        }
    }

    var code: [[String?]] {
        /*
         Metadata:
          - 0 : "XYKPool"
          - 1 : "BondingCurvePool"
          - 2 : "MulticollateralBondingCurvePool"
          - 3 : "MockPool"
          - 4 : "MockPool2"
          - 5 : "MockPool3"
          - 6 : "MockPool4"
          - 7 : "XSTPool"
          */
        switch self {
        case .smart:
            return []
        case .tbc:
            return [["MulticollateralBondingCurvePool", nil]]
        case .xyk:
            return [["XYKPool", nil]]
        }
    }

    var filterMode: PolkaswapLiquidityFilterMode {
        self == .smart ? .disabled : .allowSelected
    }

    func description(for locale: Locale) -> String {
        let preferredLocalizations = locale.rLanguages
        switch self {
        case .smart:
            return R.string.localizable
                .polkaswapMarketSmartDescription(preferredLanguages: preferredLocalizations)
        case .xyk:
            return R.string.localizable
                .polkaswapMarketXykDescription(preferredLanguages: preferredLocalizations)
        case .tbc:
            return R.string.localizable
                .polkaswapMarketTbcDescription(preferredLanguages: preferredLocalizations)
        }
    }
}
