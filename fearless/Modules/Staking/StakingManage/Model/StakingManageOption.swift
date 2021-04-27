import UIKit.UIImage

enum StakingManageOption {
    case stakingBalance
    case rewardPayouts
    case validators(count: Int?)

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .stakingBalance:
            return R.string.localizable.stakingBalanceTitle(preferredLanguages: locale.rLanguages)
        case .rewardPayouts:
            return R.string.localizable.stakingManagePayoutsTitle(preferredLanguages: locale.rLanguages)
        case .validators:
            return R.string.localizable.stakingYourValidatorsTitle(preferredLanguages: locale.rLanguages)
        }
    }

    func detailsForLocale(_ locale: Locale) -> String? {
        switch self {
        case let .validators(count):
            guard let count = count else {
                return nil
            }

            let formatter = NumberFormatter.quantity.localizableResource().value(for: locale)
            return formatter.string(from: NSNumber(value: count))
        default:
            return nil
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
