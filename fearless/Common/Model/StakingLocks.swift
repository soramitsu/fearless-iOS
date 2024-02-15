import Foundation

struct StakingLocks {
    let staked: Decimal
    let unstaking: Decimal
    let redeemable: Decimal
    let claimable: Decimal?

    var total: Decimal {
        [staked, unstaking, redeemable, claimable.or(.zero)].reduce(0, +)
    }
}
