import Foundation
import SSFUtils
import Web3

struct JoinPoolCall: Codable {
    @StringCodable var amount: BigUInt
    let poolId: String
}
