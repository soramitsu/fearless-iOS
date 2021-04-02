import UIKit

extension Chain {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .sora:
            return "SORA"
        case .polkadot:
            return "Polkadot"
        case .kusama:
            return "Kusama"
        case .westend:
            return "Westend"
        }
    }

    var icon: UIImage? {
        switch self {
        case .sora:
            return R.image.iconPolkadotSmallBg() //TODO: add sora logo
        case .polkadot:
            return R.image.iconPolkadotSmallBg()
        case .kusama:
            return R.image.iconKsmSmallBg()
        case .westend:
            return R.image.iconWestendSmallBg()
        }
    }
}
