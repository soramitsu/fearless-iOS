import Foundation
import BigInt
import FearlessUtils

struct PoolUnbondCall: Codable {
    let memberAccount: AccountId
    @StringCodable var unbondingPoints: BigUInt
}
