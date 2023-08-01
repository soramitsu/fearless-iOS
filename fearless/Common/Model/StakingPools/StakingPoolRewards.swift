import Foundation
import BigInt
import SSFUtils

struct StakingPoolRewards: Decodable {
    @StringCodable var lastRecordedRewardCounter: BigUInt
    @StringCodable var lastRecordedTotalPayouts: BigUInt
    @StringCodable var totalRewardsClaimed: BigUInt
}
