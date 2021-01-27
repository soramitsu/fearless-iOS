import Foundation

struct NominatorReward {
    let era: UInt32
    let reward: Decimal
    let validatorId: AccountId
    let claimed: Bool
}
