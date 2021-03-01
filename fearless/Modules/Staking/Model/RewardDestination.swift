import Foundation

enum RewardDestination {
    case restake
    case payout(account: AccountItem)
}
