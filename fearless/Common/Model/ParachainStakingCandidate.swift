import Foundation
import CommonWallet

struct ParachainStakingCandidateInfo: Equatable {
    let address: AccountAddress
    let owner: AccountId
    let amount: AmountDecimal
    let metadata: ParachainStakingCandidateMetadata?
    let identity: AccountIdentity?
}

struct ParachainStakingCandidate: Decodable, Equatable {
    let owner: AccountId
    let amount: AmountDecimal
}
