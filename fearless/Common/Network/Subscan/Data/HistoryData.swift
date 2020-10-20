import Foundation

struct HistoryData: Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case transactions = "transfers"
    }

    let count: Int
    let transactions: [HistoryItemData]?
}

struct HistoryItemData: Codable {
    enum CodingKeys: String, CodingKey {
        case sender = "from"
        case receiver = "to"
        case success
        case hash
        case timestamp = "block_timestamp"
        case amount
        case fee
    }

    let sender: String
    let receiver: String
    let success: Bool?
    let hash: String
    let timestamp: Int64
    let amount: String
    let fee: String
}
