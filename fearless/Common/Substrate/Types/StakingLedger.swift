import Foundation
import FearlessUtils
import BigInt

struct StakingLedger: Decodable, Equatable {
    let stash: Data
    @StringCodable var total: BigUInt
    @StringCodable var active: BigUInt
    let unlocking: [UnlockChunk]
    let claimedRewards: [StringScaleMapper<UInt32>]
}

struct UnlockChunk: Decodable, Equatable {
    @StringCodable var value: BigUInt
    @StringCodable var era: UInt32
}

extension StakingLedger {
    func redeemable(inEra activeEra: UInt32) -> BigUInt {
        unlocking.reduce(BigUInt(0)) { result, item in
            item.era <= activeEra ? (result + item.value) : result
        }
    }

    func unbonding(inEra activeEra: UInt32) -> BigUInt {
        unbondings(inEra: activeEra).reduce(BigUInt(0)) { result, item in
            result + item.value
        }
    }

    func unbondings(inEra activeEra: UInt32) -> [UnlockChunk] {
        unlocking.filter { $0.era > activeEra }
    }
}
