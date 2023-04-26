import UIKit.UIImage
import SSFUtils
import SoraFoundation

struct StakingPayoutConfirmationViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon?
    let senderName: String?
    let amount: LocalizableResource<StakeAmountViewModel>?
    let amountString: LocalizableResource<String>
}

enum PayoutConfirmViewModel {
    case accountInfo(AccountInfoViewModel)
    case restakeDestination(StakingRewardDetailsSimpleLabelViewModel)
    case rewardAmountViewModel(StakingRewardTokenUsdViewModel)
}
