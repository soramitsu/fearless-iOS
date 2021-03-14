import Foundation

struct PreparedNomination {
    let amount: Decimal
    let rewardDestination: RewardDestination
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
}
