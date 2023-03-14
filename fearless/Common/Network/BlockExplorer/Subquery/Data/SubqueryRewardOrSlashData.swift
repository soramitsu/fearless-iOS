import Foundation

struct SubqueryRewardOrSlashData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}

extension SubqueryRewardOrSlashData: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        historyElements.nodes
    }
}
