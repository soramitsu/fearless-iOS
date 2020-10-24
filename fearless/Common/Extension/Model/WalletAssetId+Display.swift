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
        case .usd:
            return nil
        }
    }

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .dot:
            return "Polkadot"
        case .kusama:
            return "Kusama"
        case .westend:
            return "Westend"
        case .usd:
            return "Usd"
        }
    }
}
