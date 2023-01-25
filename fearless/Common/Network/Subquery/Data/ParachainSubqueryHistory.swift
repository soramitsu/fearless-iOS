import Foundation
import BigInt

struct SubqueryDelegatorHistoryData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryDelegatorHistoryElement]
    }

    let delegators: HistoryElements
}

struct SubqueryDelegatorHistoryElement: Decodable {
    let id: String?
    let delegatorHistoryElements: SubqueryDelegatorHistoryNodes
}

struct SubqueryDelegatorHistoryNodes: Decodable {
    let nodes: [SubqueryDelegatorHistoryItem]
}

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
