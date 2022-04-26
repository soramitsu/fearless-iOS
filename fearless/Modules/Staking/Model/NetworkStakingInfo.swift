import Foundation
import BigInt

enum NetworkStakingInfo {
    case relaychain(
        baseInfo: BaseStakingInfo,
        relaychainInfo: RelaychainStakingInfo
    )
    case parachain(baseInfo: BaseStakingInfo)

    var baseInfo: BaseStakingInfo {
        switch self {
        case let .relaychain(baseInfo, _):
            return baseInfo
        case let .parachain(baseInfo):
            return baseInfo
        }
    }

    var relaychainInfo: RelaychainStakingInfo? {
        switch self {
        case let .relaychain(_, relaychainInfo):
            return relaychainInfo
        case .parachain:
            return nil
        }
    }
}

struct BaseStakingInfo {
    let lockUpPeriod: UInt32
    let minimalBalance: BigUInt
    let minStakeAmongActiveNominators: BigUInt
}

struct RelaychainStakingInfo {
    let stakingDuration: StakingDuration
    let totalStake: BigUInt
    let activeNominatorsCount: Int
}

extension NetworkStakingInfo {
    func calculateMinimumStake(given minNominatorBond: BigUInt?) -> BigUInt {
        let minStake = max(baseInfo.minStakeAmongActiveNominators, baseInfo.minimalBalance)

        guard let minNominatorBond = minNominatorBond else {
            return minStake
        }

        return max(minStake, minNominatorBond)
    }
}
