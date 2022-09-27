import Foundation
import FearlessUtils
import SoraFoundation

struct StakingBondMoreConfirmViewModel {
    let accountViewModel: TitleMultiValueViewModel?
    let amountViewModel: TitleMultiValueViewModel?
    let collatorViewModel: TitleMultiValueViewModel?
    let senderIcon: DrawableIcon?
    let amount: LocalizableResource<StakeAmountViewModel>?
    let collatorIcon: DrawableIcon?
}
