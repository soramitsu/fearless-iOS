import UIKit.UIImage

enum PayoutConfirmViewModel {
    case accountInfo(AccountInfoViewModel)
    case restakeDestination(StakingRewardDetailsSimpleLabelViewModel)
    case rewardAmountViewModel(StakingRewardTokenUsdViewModel)
}
