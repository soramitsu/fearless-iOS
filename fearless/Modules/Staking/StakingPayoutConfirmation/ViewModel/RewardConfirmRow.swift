import UIKit.UIImage

struct PayoutAccountViewModel {
    let title: String
    let name: String
    let icon: UIImage?
}

struct PayoutRewardAmountViewModel {
    let title: String
    let tokenAmount: String
    let fiatAmount: String
}

enum RewardConfirmRow {
    case accountInfo(PayoutAccountViewModel)
    case restakeDestination(TitleWithSubtitleViewModel)
    case rewardAmountViewModel(PayoutRewardAmountViewModel)
}
