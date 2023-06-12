import Foundation
import Web3
import SSFUtils

struct StakingPoolRewards: Decodable {
    @StringCodable var lastRecordedRewardCounter: BigUInt
    @StringCodable var lastRecordedTotalPayouts: BigUInt
    @StringCodable var totalRewardsClaimed: BigUInt
}
