import Foundation
import SSFUtils
import SoraFoundation

struct StakingBondMoreConfirmViewModel {
    let accountViewModel: TitleMultiValueViewModel?
    let amountViewModel: TitleMultiValueViewModel?
    let senderIcon: DrawableIcon?
    let amount: LocalizableResource<StakeAmountViewModel>?
}
