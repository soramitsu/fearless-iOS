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
        }
    }
}
