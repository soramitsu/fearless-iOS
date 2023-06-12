import Foundation
import Web3

struct ErasRewardDistribution {
    let totalValidatorRewardByEra: [EraIndex: BigUInt]
    let validatorPointsDistributionByEra: [EraIndex: EraRewardPoints]
}
