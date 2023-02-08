import Foundation
import CommonWallet

struct ParachainStakingCandidateInfo: Equatable {
    let address: AccountAddress
    let owner: AccountId
    let amount: AmountDecimal
    let metadata: ParachainStakingCandidateMetadata?
    let identity: AccountIdentity?
    let subqueryData: CollatorAprInfoProtocol?

    var oversubscribed: Bool {
        metadata?.topCapacity == .full
    }

    var hasIdentity: Bool {
        identity != nil
    }

    var stakeReturn: Decimal {
        Decimal.zero
    }

    static func == (lhs: ParachainStakingCandidateInfo, rhs: ParachainStakingCandidateInfo) -> Bool {
        lhs.address == rhs.address
            && lhs.owner == rhs.owner
            && lhs.amount == rhs.amount
            && lhs.metadata == rhs.metadata
            && lhs.identity == rhs.identity
            && lhs.subqueryData?.apr == rhs.subqueryData?.apr
            && lhs.subqueryData?.collatorId == rhs.subqueryData?.collatorId
    }
}

struct ParachainStakingCandidate: Decodable, Equatable {
    let owner: AccountId
    let amount: AmountDecimal
}
