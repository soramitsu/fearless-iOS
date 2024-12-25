import Foundation
import SSFModels

struct ExistingBonding {
    let stashAddress: AccountAddress
    let controllerAccount: ChainAccountResponse
    let amount: Decimal
    let rewardDestination: RewardDestination<AccountAddress>
    let selectedTargets: [SelectedValidatorInfo]?
}
