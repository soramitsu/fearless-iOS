import Foundation

struct SubqueryDelegatorHistoryData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryDelegatorHistoryElement]
    }

    let delegators: HistoryElements
}

extension SubqueryDelegatorHistoryData: RewardHistoryResponseProtocol {
    func rewardHistory(for address: String) -> [RewardHistoryItemProtocol] {
        delegators.nodes.first { element in
            element.id == address
        }?.delegatorHistoryElements.nodes.filter { item in
            item.delegatorId == address
        } ?? []
    }
}
