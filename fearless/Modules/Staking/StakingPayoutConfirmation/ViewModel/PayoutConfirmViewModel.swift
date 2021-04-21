import UIKit.UIImage

struct PayoutAccountViewModel {
    let title: String
    let name: String
    let icon: UIImage?
}

struct PayoutRewardAmountViewModel {
    let title: String
    let priceData: BalanceViewModelProtocol
}

enum PayoutConfirmViewModel {
    case accountInfo(PayoutAccountViewModel)
    case restakeDestination(TitleWithSubtitleViewModel)
    case rewardAmountViewModel(PayoutRewardAmountViewModel)
}
