import Foundation
import SSFUtils
import SoraFoundation

struct SelectedValidatorViewModel {
    let name: String?
    let address: String
    let icon: DrawableIcon?
}

struct SelectValidatorsConfirmViewModel {
    let senderAddress: String?
    let senderName: String
    let amount: BalanceViewModelProtocol?
    let rewardDestination: RewardDestinationTypeViewModel?
    let validatorsCount: Int?
    let maxValidatorCount: Int?
    let selectedCollatorViewModel: SelectedValidatorViewModel?
    let stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>?
    let poolName: String?
}
