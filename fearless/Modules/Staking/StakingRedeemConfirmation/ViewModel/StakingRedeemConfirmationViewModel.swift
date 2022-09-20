import Foundation
import FearlessUtils
import SoraFoundation

struct StakingRedeemConfirmationViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon?
    let senderName: String?
    let stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>?
    let amountString: LocalizableResource<String>
    let title: LocalizableResource<String>
    let collatorName: String?
    let collatorIcon: DrawableIcon?
}
