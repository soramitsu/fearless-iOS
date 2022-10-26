import Foundation
import FearlessUtils
import BigInt

struct DelegateCall: Codable {
    let candidate: AccountId
    @StringCodable var amount: BigUInt
    @StringCodable var autoCompound: UInt8
    @StringCodable var candidateDelegationCount: UInt32
    @StringCodable var candidateAutoCompoundingDelegationCount: UInt32
    @StringCodable var delegationCount: UInt32
}
