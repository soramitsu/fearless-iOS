import Foundation
import SSFUtils
import BigInt

struct DelegateCall: Codable {
    let candidate: AccountId
    @StringCodable var amount: BigUInt
    @StringCodable var candidateDelegationCount: UInt32
    @StringCodable var delegationCount: UInt32
}
