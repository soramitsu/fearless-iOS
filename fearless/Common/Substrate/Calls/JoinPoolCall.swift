import Foundation
import SSFUtils
import BigInt

struct JoinPoolCall: Codable {
    @StringCodable var amount: BigUInt
    let poolId: String
}
