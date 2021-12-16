import Foundation

struct ExistingBonding {
    let stashAddress: AccountAddress
    let amount: Decimal
    let rewardDestination: RewardDestination<AccountAddress>
    let selectedTargets: [SelectedValidatorInfo]?
}
