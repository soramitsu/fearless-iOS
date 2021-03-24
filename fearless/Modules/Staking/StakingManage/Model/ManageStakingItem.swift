import UIKit.UIImage

enum ManageStakingItem {
    case rewardPayouts

    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .rewardPayouts:
            return "Reward payouts"
        }
    }

    var icon: UIImage? {
        switch self {
        case .rewardPayouts:
            return R.image.iconPolkadotSmallBg()
        }
    }
}
