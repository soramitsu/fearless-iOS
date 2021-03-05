import Foundation
import BigInt

struct EraStakingInfo {
    let totalStake: BigUInt
    let minStake: BigUInt
    let activeNominations: UInt
    let lockUpPeriodInDays: UInt
}
