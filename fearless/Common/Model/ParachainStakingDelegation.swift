import Foundation
import CommonWallet
import BigInt
import FearlessUtils

struct ParachainStakingDelegations: Codable, Equatable {
    let delegations: [ParachainStakingDelegation]
}

struct ParachainStakingDelegation: Codable, Equatable {
    let owner: AccountId
    @StringCodable var amount: BigUInt
}

struct ParachainStakingDelegationInfo {
    let delegation: ParachainStakingDelegation
    let collator: ParachainStakingCandidateInfo
}
