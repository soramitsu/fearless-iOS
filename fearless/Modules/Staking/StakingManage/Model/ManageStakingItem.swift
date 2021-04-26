import UIKit.UIImage

enum ManageStakingItem {
    case stakingBalance
    case rewardPayouts
    case validators(count: Int?)

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .stakingBalance:
            return "Staking balance" // TODO:
        case .rewardPayouts:
            return R.string.localizable.stakingManagePayoutsTitle(preferredLanguages: locale.rLanguages)
        case .validators:
            return "Your validators"
        }
    }

    var icon: UIImage? {
        switch self {
        case .stakingBalance:
            return R.image.iconStakingBalance()
        case .rewardPayouts:
            return R.image.iconLightning()
        case .validators:
            return R.image.iconValidators()
        }
    }
}
