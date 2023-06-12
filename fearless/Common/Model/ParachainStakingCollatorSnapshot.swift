import Foundation
import SSFUtils
import Web3

struct ParachainStakingCollatorSnapshot: Codable, Equatable {
    @StringCodable var bond: BigUInt
    @StringCodable var total: BigUInt
    let delegations: [ParachainStakingDelegation]
}
