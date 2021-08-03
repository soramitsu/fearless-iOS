import Foundation

struct ExistingBonding {
    let stashAddress: AccountAddress
    let controllerAccount: AccountItem
    let amount: Decimal
    let rewardDestination: RewardDestination<AccountAddress>
    let selectedTargets: [SelectedValidatorInfo]?
}
