import Foundation
import BigInt

enum NetworkStakingInfo {
    case relaychain(
        baseInfo: BaseStakingInfo,
        relaychainInfo: RelaychainStakingInfo
    )
    case parachain(
        baseInfo: BaseStakingInfo,
        parachainInfo: ParachainStakingInfo
    )

    var baseInfo: BaseStakingInfo {
        switch self {
        case let .relaychain(baseInfo, _):
            return baseInfo
        case let .parachain(baseInfo, _):
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

    var parachainInfo: ParachainStakingInfo? {
        switch self {
        case .relaychain:
            return nil
        case let .parachain(_, parachainInfo):
            return parachainInfo
        }
    }
}

struct BaseStakingInfo {
    let lockUpPeriod: UInt32
    let minimalBalance: BigUInt
    let minStakeAmongActiveNominators: BigUInt
}

struct ParachainStakingInfo {
    let rewardPaymentDelay: UInt32
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
