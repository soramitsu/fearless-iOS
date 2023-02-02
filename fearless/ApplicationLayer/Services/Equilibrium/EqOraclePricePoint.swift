import Foundation
import BigInt
import FearlessUtils

struct EqOraclePricePoint: Decodable {
    @StringCodable var blockNumber: BigUInt
    @StringCodable var timestamp: BigUInt
    @StringCodable var lastFinRecalcTimestamp: UInt32
    @StringCodable var price: BigUInt
    let dataPoints: [EqOracleDataPoints]
}

struct EqOracleDataPoints: Decodable {
    @StringCodable var price: BigUInt
    let accountId: AccountId
    @StringCodable var blockNumber: BigUInt
    @StringCodable var timestamp: BigUInt
}
