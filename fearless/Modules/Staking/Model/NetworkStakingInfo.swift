import Foundation
import BigInt

struct NetworkStakingInfo {
    let totalStake: BigUInt
    let minStakeAmongActiveNominators: BigUInt
    let minimalBalance: BigUInt
    let activeNominatorsCount: Int
    let lockUpPeriod: UInt32
}

extension NetworkStakingInfo {
    func calculateMinimumStake(given minNominatorBond: BigUInt?) -> BigUInt {
        let minStake = max(minStakeAmongActiveNominators, minimalBalance)

        guard let minNominatorBond = minNominatorBond else {
            return minStake
        }

        return max(minStake, minNominatorBond)
    }
}
