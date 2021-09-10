import Foundation
import CommonWallet

struct TotalRewardItem: Codable, Equatable {
    let address: String
    let amount: AmountDecimal
}
