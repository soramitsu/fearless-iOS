import Foundation
import IrohaCrypto

extension SNAddressType {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .polkadotMain, .polkadotSecondary:
            return "Polkadot"
        case .kusamaMain, .kusamaSecondary:
            return "Kusama"
        default:
            return "Westend"
        }
    }

    var icon: UIImage? {
        switch self {
        case .polkadotMain, .polkadotSecondary:
            return R.image.iconPolkadotSmall()
        case .kusamaMain, .kusamaSecondary:
            return R.image.iconKsmSmall()
        default:
            return R.image.iconWestendSmall()
        }
    }
}
