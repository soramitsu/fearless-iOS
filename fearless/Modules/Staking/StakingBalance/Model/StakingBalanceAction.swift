import Foundation
import UIKit.UIImage

enum StakingBalanceAction {
    case bondMore
    case unbond
    case redeem
}

extension StakingBalanceAction {
    // TODO:
    func title(for _: Locale) -> String {
        switch self {
        case .bondMore:
            return "Bond more"
        case .unbond:
            return "Unbond"
        case .redeem:
            return "Redeem"
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
