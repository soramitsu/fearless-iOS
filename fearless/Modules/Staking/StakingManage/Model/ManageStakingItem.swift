import UIKit.UIImage

enum ManageStakingItem: CaseIterable {
    case stakingBalance
    case rewardPayouts

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .stakingBalance:
            return "Staking balance" // TODO:
        case .rewardPayouts:
            return R.string.localizable.stakingManagePayoutsTitle(preferredLanguages: locale.rLanguages)
        }
    }

    var icon: UIImage? {
        switch self {
        case .stakingBalance:
            return R.image.iconStakingBalance()
        case .rewardPayouts:
            return R.image.iconLightning()
        }
    }
}
