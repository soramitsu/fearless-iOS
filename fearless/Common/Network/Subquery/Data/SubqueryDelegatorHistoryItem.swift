import Foundation
import FearlessUtils
import CommonWallet
import IrohaCrypto
import BigInt

struct SubqueryDelegatorHistoryItem: Decodable, RewardHistoryItemProtocol {
    let id: String
    let type: SubqueryDelegationAction
    let timestampInSeconds: String
    let blockNumber: Int
    let amount: BigUInt
}

extension SubqueryDelegatorHistoryData: RewardHistoryResponseProtocol {
    func rewardHistory(for address: String) -> [RewardHistoryItemProtocol] {
        delegators.nodes.first { element in
            element.id == address
        }?.delegatorHistoryElements.nodes ?? []
    }
}
