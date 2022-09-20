import Foundation
import BigInt
import FearlessUtils

struct PoolWithdrawUnbondedCall: Codable {
    let memberAccount: AccountId
    @StringCodable var numSlashingSpans: UInt32
}
