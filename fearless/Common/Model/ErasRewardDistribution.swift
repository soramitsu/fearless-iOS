import Foundation
import BigInt

struct ErasRewardDistribution {
    let totalValidatorRewardByEra: [EraIndex: BigUInt]
    let validatorPointsDistributionByEra: [EraIndex: EraRewardPoints]
}
