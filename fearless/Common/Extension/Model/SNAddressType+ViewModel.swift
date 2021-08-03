import Foundation
import IrohaCrypto

extension SNAddressType {
    func titleForLocale(_: Locale) -> String {
        switch self {
        case .polkadotMain, .polkadotSecondary:
            return "Polkadot"
        case .kusamaMain:
            return "Kusama"
        case .kusamaSecondary:
            return "Rococo"
        default:
            return "Westend"
        }
    }

    var icon: UIImage? {
        switch self {
        case .polkadotMain, .polkadotSecondary:
            return R.image.iconPolkadotSmallBg()
        case .kusamaMain, .kusamaSecondary:
            return R.image.iconKsmSmallBg()
        default:
            return R.image.iconWestendSmallBg()
        }
    }

    static var supported: [SNAddressType] {
        [.kusamaMain, .polkadotMain, .genericSubstrate, .kusamaSecondary]
    }
}
