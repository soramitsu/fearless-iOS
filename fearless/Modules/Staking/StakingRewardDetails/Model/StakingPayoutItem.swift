import Foundation

struct StakingPayoutItem {
    let validator: Data
    let era: EraIndex
    let reward: Decimal
}
