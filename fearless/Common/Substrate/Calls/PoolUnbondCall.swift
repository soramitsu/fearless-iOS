import Foundation
import BigInt
import FearlessUtils

struct PoolUnbondCall: Codable {
    let memberAccount: MultiAddress
    @StringCodable var unbondingPoints: BigUInt
}
