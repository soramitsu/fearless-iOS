import Foundation
import SSFUtils
import BigInt

struct DelegatorBondMoreCall: Codable {
    let candidate: AccountId
    @StringCodable var more: BigUInt
}
