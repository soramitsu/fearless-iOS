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

struct SoraSubqueryRewardOrSlashData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SoraSubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}

extension SoraSubqueryRewardOrSlashData: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        historyElements.nodes
    }
}

struct SoraSubqueryHistoryElement: Decodable, RewardOrSlashData {
    enum CodingKeys: String, CodingKey {
        case timestamp
        case id
        case address
        case data
        case method
        case module
        case blockHash
        case blockHeight
    }

    let timestamp: String
    let id: String
    let address: String
    let data: SoraSubqueryHistoryElementData
    let method: String
    let module: String
    let blockHash: String
    let blockHeight: Int

    var identifier: String {
        id
    }

    var rewardInfo: (any RewardOrSlash)? {
        self
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let timestampInt = try? container.decode(Int.self, forKey: .timestamp) {
            timestamp = String(timestampInt)
        } else {
            timestamp = ""
        }
        id = try container.decode(String.self, forKey: .id)
        address = try container.decode(String.self, forKey: .address)
        data = try container.decode(SoraSubqueryHistoryElementData.self, forKey: .data)
        method = try container.decode(String.self, forKey: .method)
        module = try container.decode(String.self, forKey: .module)
        blockHash = try container.decode(String.self, forKey: .blockHash)
        blockHeight = try container.decode(Int.self, forKey: .blockHeight)
    }
}

extension SoraSubqueryHistoryElement: RewardOrSlash {
    var amount: String {
        data.amount
    }

    var isReward: Bool {
        true
    }

    var era: Int? {
        data.era
    }

    var validator: String? {
        nil
    }

    var stash: String? {
        data.stash
    }

    var eventIdx: String? {
        id
    }

    var assetId: String? {
        nil
    }
}

struct SoraSubqueryHistoryElementData: Decodable {
    let era: Int
    let payee, stash: String
    let amount, amountUSD: String
}
