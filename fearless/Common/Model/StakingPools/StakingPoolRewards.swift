import Foundation
import BigInt
import FearlessUtils

struct StakingPoolRewards: Decodable {
    @StringCodable var lastRecordedRewardCounter: BigUInt
    @StringCodable var lastRecordedTotalPayouts: BigUInt
    @StringCodable var totalRewardsClaimed: BigUInt
}
