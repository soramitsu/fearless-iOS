import Foundation
import FearlessUtils
import SoraFoundation

struct StakingUnbondConfirmViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon?
    let senderName: String?
    let collatorName: String?
    let collatorIcon: DrawableIcon?
    let stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>?
    let amountString: LocalizableResource<String>
    let hints: LocalizableResource<[TitleIconViewModel]>
}
