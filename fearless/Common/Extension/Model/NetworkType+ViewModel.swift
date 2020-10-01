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
            return R.image.iconPolkadotSmallBg()
        case .kusamaMain, .kusamaSecondary:
            return R.image.iconKsmSmallBg()
        default:
            return R.image.iconWestendSmallBg()
        }
    }

    static var supported: [SNAddressType] {
        [.kusamaMain, .polkadotMain, .genericSubstrate]
    }

    var genesisHash: String {
        switch self {
        case .polkadotMain, .polkadotSecondary:
            return "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        case .kusamaMain, .kusamaSecondary:
            return "b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"
        default:
            return "e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e"
        }
    }
}
