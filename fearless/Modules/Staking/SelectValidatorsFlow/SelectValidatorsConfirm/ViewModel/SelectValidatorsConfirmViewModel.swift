import Foundation
import FearlessUtils
import SoraFoundation

struct SelectedValidatorViewModel {
    let name: String?
    let address: String
    let icon: DrawableIcon?
}

struct SelectValidatorsConfirmViewModel {
    let senderIcon: DrawableIcon?
    let senderName: String
    let amount: String
    let rewardDestination: RewardDestinationTypeViewModel?
    let validatorsCount: Int?
    let maxValidatorCount: Int?
    let selectedCollatorViewModel: SelectedValidatorViewModel?
    let stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>?
    let poolName: String?
}
