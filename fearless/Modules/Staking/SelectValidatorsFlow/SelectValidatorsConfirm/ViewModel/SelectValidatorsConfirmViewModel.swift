import Foundation
import SSFUtils
import SoraFoundation

struct SelectValidatorsConfirmViewModel {
    let senderAddress: String?
    let senderName: String
    let amount: BalanceViewModelProtocol?
    let rewardDestination: RewardDestinationTypeViewModel?
    let validatorsCount: Int?
    let maxValidatorCount: Int?
    let stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>?
    let poolName: String?
}
