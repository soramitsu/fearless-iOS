import Foundation
import FearlessUtils
import BigInt

struct DyAccountInfo: Codable, Equatable {
    @StringCodable var nonce: UInt32
    @StringCodable var consumers: UInt32
    @StringCodable var providers: UInt32
    let data: DyAccountData
}

struct DyAccountData: Codable, Equatable {
    @StringCodable var free: BigUInt
    @StringCodable var reserved: BigUInt
    @StringCodable var miscFrozen: BigUInt
    @StringCodable var feeFrozen: BigUInt
}

extension DyAccountData {
    var total: BigUInt { free + reserved }
    var frozen: BigUInt { reserved + locked }
    var locked: BigUInt { max(miscFrozen, feeFrozen) }
    var available: BigUInt { free - locked }
}
