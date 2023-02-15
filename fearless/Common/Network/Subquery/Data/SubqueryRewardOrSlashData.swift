import Foundation

protocol RewardOrSlash {
    var amount: String { get }
    var isReward: Bool { get }
    var era: Int? { get }
    var validator: String? { get }
    var stash: String? { get }
    var eventIdx: String? { get }
    var assetId: String? { get }
}

protocol RewardOrSlashData {
    var identifier: String { get }
    var timestamp: String { get }
    var address: String { get }
    var rewardInfo: RewardOrSlash? { get }
}

protocol RewardOrSlashResponse {
    var data: [RewardOrSlashData] { get }
}

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
