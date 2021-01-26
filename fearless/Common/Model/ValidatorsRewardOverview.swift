import Foundation

struct ValidatorsRewardOverview {
    let initialEra: UInt32
    let totalValidatorsReward: [Balance]
    let rewardsPoints: [EraRewardPoints]
}
