import Foundation

struct SubscanRewardData: Codable {
    enum CodingKeys: String, CodingKey {
        case count = "count"
        case items = "list"
    }

    let count: Int
    let items: [SubscanRewardItemData]
}

struct SubscanRewardItemData: Codable {
    enum CodingKeys: String, CodingKey {
        case recordId = "event_index"
        case blockNumber = "block_num"
        case extrinsicIndex = "extrinsic_idx"
        case extrinsicHash = "extrinsic_hash"
        case moduleId = "module_id"
        case params = "params"
        case eventId = "event_id"
        case eventIndex = "event_idx"
        case amount = "amount"
        case timestamp = "block_timestamp"
        case slashKton = "slash_kton"
    }

    let recordId: String
    let blockNumber: Int64
    let extrinsicIndex: Int
    let extrinsicHash: String
    let moduleId: String
    let params: String
    let eventId: String
    let eventIndex: Int
    let amount: String
    let timestamp: Int64
    let slashKton: String
}
