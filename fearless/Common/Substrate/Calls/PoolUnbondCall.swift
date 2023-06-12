import Foundation
import Web3
import SSFUtils

struct PoolUnbondCallOld: Codable {
    let memberAccount: AccountId
    @StringCodable var unbondingPoints: BigUInt
}

struct PoolUnbondCall: Codable {
    let memberAccount: MultiAddress
    @StringCodable var unbondingPoints: BigUInt
}
