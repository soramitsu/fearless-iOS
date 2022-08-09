import Foundation
import FearlessUtils
import BigInt

struct JoinPoolCall: Codable {
    @StringCodable var amount: BigUInt
    let poolId: String
}
