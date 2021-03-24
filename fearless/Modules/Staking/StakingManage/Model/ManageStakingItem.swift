import UIKit.UIImage

enum ManageStakingItem {
    case rewardPayouts

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .rewardPayouts:
            return R.string.localizable.stakingManagePayoutsTitle(preferredLanguages: locale.rLanguages)
        }
    }

    var icon: UIImage? {
        switch self {
        case .rewardPayouts:
            return R.image.iconLightning()
        }
    }
}
