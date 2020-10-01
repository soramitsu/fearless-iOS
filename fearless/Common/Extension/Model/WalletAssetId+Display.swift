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
