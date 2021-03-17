import Foundation
import FearlessUtils
import BigInt

struct DyStakingLedger: Decodable, Equatable {
    let stash: Data
    @StringCodable var total: BigUInt
    @StringCodable var active: BigUInt
    let unlocking: [DyUnlockChunk]
    let claimedRewards: [StringScaleMapper<UInt32>]
}

struct DyUnlockChunk: Decodable, Equatable {
    @StringCodable var value: BigUInt
    @StringCodable var era: UInt32
}
