import Foundation
import BigInt
import FearlessUtils

struct StakingPoolMember: Decodable {
    let poolId: UInt32
    @StringCodable var points: BigUInt
    @StringCodable var lastRecordedRewardCounter: BigUInt
    let unbondingEras: [UnlockChunk]
}
