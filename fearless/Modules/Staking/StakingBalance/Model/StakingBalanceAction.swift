import Foundation
import UIKit.UIImage

enum StakingBalanceAction {
    case bondMore
    case unbond
    case redeem
}

extension StakingBalanceAction {
    func title(for locale: Locale) -> String {
        switch self {
        case .bondMore:
            return R.string.localizable.stakingBondMore_v190(preferredLanguages: locale.rLanguages)
        case .unbond:
            return R.string.localizable.stakingUnbond_v190(preferredLanguages: locale.rLanguages)
        case .redeem:
            return R.string.localizable.stakingRedeem(preferredLanguages: locale.rLanguages)
        }
    }

    var iconImage: UIImage? {
        switch self {
        case .bondMore:
            return R.image.iconBondMore()
        case .unbond:
            return R.image.iconUnbond()
        case .redeem:
            return R.image.iconRedeem()
        }
    }
}
