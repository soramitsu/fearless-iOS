import Foundation
import FearlessUtils
import BigInt

struct DelegateCall: Codable {
    let candidate: AccountId
    @StringCodable var amount: BigUInt
    let candidateDelegationCount: UInt32
    let delegationCount: UInt32
}
