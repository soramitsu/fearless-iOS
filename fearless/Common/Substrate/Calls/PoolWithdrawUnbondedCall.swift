import Foundation
import BigInt
import FearlessUtils

struct PoolWithdrawUnbondedCall: Codable {
    let memberAccount: MultiAddress
    @StringCodable var numSlashingSpans: UInt32
}
