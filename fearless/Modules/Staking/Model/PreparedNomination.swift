import Foundation

struct PreparedNomination {
    let amount: Decimal
    let rewardDestination: RewardDestination
    let fee: Decimal
    let targets: [SelectedValidatorInfo]
}
