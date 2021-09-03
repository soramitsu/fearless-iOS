import Foundation
import CommonWallet

struct TotalRewardItem: Codable, Equatable {
    let address: String
    let lastId: String
    let amount: AmountDecimal
}
