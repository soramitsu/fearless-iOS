import Foundation
import SSFUtils
import CommonWallet
import IrohaCrypto
import BigInt

struct SubqueryDelegatorHistoryItem: Decodable, RewardHistoryItemProtocol, DelegatorHistoryItem {
    let id: String
    let type: SubqueryDelegationAction
    let timestampInSeconds: String
    let blockNumber: Int
    let amount: BigUInt
}
