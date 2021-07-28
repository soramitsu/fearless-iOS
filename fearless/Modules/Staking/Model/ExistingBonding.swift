import Foundation

struct ExistingBonding {
    let stashAddress: String
    let controllerAccount: AccountItem
    let amount: Decimal
    let rewardDestination: RewardDestination<AccountAddress>
    let selectedTargets: [SelectedValidatorInfo]?
}
