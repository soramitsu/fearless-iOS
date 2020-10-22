import Foundation

struct SubscanHistoryData: Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case transactions = "transfers"
    }

    let count: Int
    let transactions: [SubscanHistoryItemData]?
}

struct SubscanHistoryItemData: Codable {
    enum CodingKeys: String, CodingKey {
        case sender = "from"
        case receiver = "to"
        case success
        case hash
        case timestamp = "block_timestamp"
        case amount
        case fee
        case blockNumber = "block_num"
        case finalized
    }

    let sender: String
    let receiver: String
    let success: Bool?
    let finalized: Bool?
    let hash: String
    let timestamp: Int64
    let amount: String
    let fee: String
    let blockNumber: Int64?
}
