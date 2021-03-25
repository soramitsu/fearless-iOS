import Foundation
import CommonWallet

struct StakingConfirmationModel {
    let wallet: DisplayAddress
    let amount: Decimal
    let rewardDestination: RewardDestination<DisplayAddress>
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
}
