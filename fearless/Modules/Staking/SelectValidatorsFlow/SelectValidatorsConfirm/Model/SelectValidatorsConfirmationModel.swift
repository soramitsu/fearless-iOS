import Foundation
import CommonWallet

struct SelectValidatorsConfirmationModel {
    let wallet: DisplayAddress
    let amount: Decimal
    let rewardDestination: RewardDestination<DisplayAddress>
    let targets: [SelectedValidatorInfo]
    let maxTargets: Int
    let hasExistingBond: Bool
    let hasExistingNomination: Bool
}
