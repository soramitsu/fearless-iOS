import Foundation
import SSFModels

struct InitiatedBonding {
    let amount: Decimal
    let rewardDestination: RewardDestination<ChainAccountResponse>
}
