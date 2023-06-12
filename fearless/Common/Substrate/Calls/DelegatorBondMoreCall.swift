import Foundation
import SSFUtils
import Web3

struct DelegatorBondMoreCall: Codable {
    let candidate: AccountId
    @StringCodable var more: BigUInt
}
