import Foundation

struct SelectValidatorsConfirmRelaychainModel {
    let wallet: DisplayAddress
    let amount: Decimal
    let rewardDestination: RewardDestination<DisplayAddress>
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
    let hasExistingBond: Bool
    let hasExistingNomination: Bool
}

struct SelectValidatorsConfirmParachainModel {
    let wallet: DisplayAddress
    let amount: Decimal
    let target: ParachainStakingCandidateInfo
    let maxTargets: Int
}
