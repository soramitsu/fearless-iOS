import Foundation
import CommonWallet

struct ParachainStakingCandidate: Codable, Equatable {
    let owner: AccountId
    let amount: AmountDecimal
}
