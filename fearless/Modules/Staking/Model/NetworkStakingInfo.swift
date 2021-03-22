import Foundation
import BigInt

struct NetworkStakingInfo {
    var totalStake: BigUInt
    var minimalStake: BigUInt
    var activeNominatorsCount: Int
    var lockUpPeriod: UInt32
}
