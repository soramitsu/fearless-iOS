import Foundation
import CommonWallet

struct TotalRewardItem: Codable {
    let address: String
    let blockNumber: UInt64
    let extrinsicIndex: UInt16
    let amount: AmountDecimal
}
