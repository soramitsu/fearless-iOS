import Foundation
import FearlessUtils
import BigInt

struct DelegatorBondMoreCall: Codable {
    let candidate: AccountId
    @StringCodable var more: BigUInt
}
