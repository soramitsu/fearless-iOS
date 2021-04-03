import UIKit.UIImage

enum StakingRewardStatus {
    case claimable
    case received
}

extension StakingRewardStatus {
    func titleForLocale(_ locale: Locale?) -> String {
        switch self {
        case .claimable:
            return R.string.localizable
                .stakingRewardDetailsStatusClaimable(preferredLanguages: locale?.rLanguages)
        case .received:
            return R.string.localizable
                .stakingRewardDetailsStatusReceived(preferredLanguages: locale?.rLanguages)
        }
    }

    var icon: UIImage? {
        switch self {
        case .claimable:
            return R.image.iconTxPending()
        case .received:
            return R.image.iconValid()
        }
    }
}
