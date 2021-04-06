import UIKit

extension Chain {
    func titleForLocale(_: Locale) -> String {
        switch self {
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
        case .polkadot:
            return R.image.iconPolkadotSmallBg()
        case .kusama:
            return R.image.iconKsmSmallBg()
        case .westend:
            return R.image.iconWestendSmallBg()
        }
    }

    var extrinsicIcon: UIImage? {
        switch self {
        case .polkadot:
            return R.image.iconPolkadotExtrinsic()
        case .kusama:
            return R.image.iconKusamaExtrinsic()
        case .westend:
            return R.image.iconWestendExtrinsic()
        }
    }
}
