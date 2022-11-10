import Foundation

enum StakingPoolMainError {
    case balanceError(error: Error)
    case priceError(error: Error)
    case networkInfoError(error: Error)
    case stakeInfoError(error: Error)
    case eraStakersInfoError(error: Error)
    case poolRewardsError(error: Error)
    case nominationError(error: Error)
}
