import UIKit

extension Chain {
    func titleForLocale(_: Locale) -> String {
        switch self {
        case .polkadot: return "Polkadot"
        case .kusama: return "Kusama"
        case .westend: return "Westend"
        case .rococo: return "Rococo"

        #if F_DEV
            case .moonbeam: return "Moonbeam"
        #endif
        }
    }

    var icon: UIImage? {
        switch self {
        case .polkadot: return R.image.iconPolkadotSmallBg()
        case .kusama: return R.image.iconKsmSmallBg()
        case .westend: return R.image.iconWestendSmallBg()
        case .rococo: return R.image.iconKsmSmallBg()

        #if F_DEV
            case .moonbeam: return R.image.iconMoonbeamSmallBg()
        #endif
        }
    }

    var extrinsicIcon: UIImage? {
        switch self {
        case .polkadot: return R.image.iconPolkadotExtrinsic()
        case .kusama: return R.image.iconKusamaExtrinsic()
        case .westend: return R.image.iconWestendExtrinsic()
        case .rococo: return R.image.iconKusamaExtrinsic()

        #if F_DEV
            case .moonbeam: return R.image.iconMoonbeamExtrinsic()
        #endif
        }
    }
}
