import Foundation
import CommonWallet

struct StakingConfirmationModel {
    let stash: DisplayAddress
    let amount: Decimal
    let rewardDestination: RewardDestination<DisplayAddress>
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
}
