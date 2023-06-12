import Foundation
import Web3
import SSFUtils

struct PoolWithdrawUnbondedCall: Codable {
    let memberAccount: MultiAddress
    @StringCodable var numSlashingSpans: UInt32
}
