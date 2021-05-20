import UIKit

extension WalletAssetId {
    var icon: UIImage? {
        switch self {
        case .dot:
            return R.image.iconPolkadotSmallBg()
        case .kusama:
            return R.image.iconKsmSmallBg()
        case .westend:
            return R.image.iconWestendSmallBg()
        case .roc:
            return R.image.iconKsmSmallBg()
        case .usd:
            return nil
        }
    }

    var assetIcon: UIImage? {
        switch self {
        case .dot:
            return R.image.iconPolkadotAsset()
        case .kusama:
            return R.image.iconKsmAsset()
        case .westend:
            return R.image.iconWestendAsset()
        case .roc:
            return R.image.iconKsmAsset()
        case .usd:
            return nil
        }
    }

    func titleForLocale(_: Locale) -> String {
        switch self {
        case .dot:
            return "Polkadot"
        case .kusama:
            return "Kusama"
        case .westend:
            return "Westend"
        case .roc:
            return "Rococo"
        case .usd:
            return "Usd"
        }
    }
}
