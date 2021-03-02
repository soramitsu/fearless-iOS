import Foundation
import FearlessUtils
import BigInt

struct StakingLedger: ScaleDecodable {
    let stash: AccountId
    let total: BigUInt
    let active: BigUInt
    let unlocking: [UnlockChunk]
    let claimedRewards: [UInt32]

    init(scaleDecoder: ScaleDecoding) throws {
        stash = try AccountId(scaleDecoder: scaleDecoder)
        total = try BigUInt(scaleDecoder: scaleDecoder)
        active = try BigUInt(scaleDecoder: scaleDecoder)
        unlocking = try [UnlockChunk](scaleDecoder: scaleDecoder)
        claimedRewards = try [UInt32](scaleDecoder: scaleDecoder)
    }
}

extension StakingLedger {
    func redeemable(inEra activeEra: UInt32) -> BigUInt {
        unlocking.reduce(BigUInt(0)) { (result, item) in
            item.era <= activeEra ? (result + item.value) : result
        }
    }

    func unbounding(inEra activeEra: UInt32) -> BigUInt {
        unlocking.reduce(BigUInt(0)) { (result, item) in
            item.era > activeEra ? (result + item.value) : result
        }
    }
}
