import Foundation
import SSFUtils
import FearlessFoundation

struct StakingBondMoreConfirmViewModel {
    let accountViewModel: TitleMultiValueViewModel?
    let amountViewModel: TitleMultiValueViewModel?
    let collatorViewModel: TitleMultiValueViewModel?
    let senderIcon: DrawableIcon?
    let amount: LocalizableResource<StakeAmountViewModel>?
    let collatorIcon: DrawableIcon?
}
