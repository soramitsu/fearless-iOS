import Foundation
import BigInt
import SSFUtils

struct PoolWithdrawUnbondedCall: Codable {
    let memberAccount: MultiAddress
    @StringCodable var numSlashingSpans: UInt32
}
