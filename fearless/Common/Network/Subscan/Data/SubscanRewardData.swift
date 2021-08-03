import Foundation

struct SubscanRewardData: Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case items = "list"
    }

    let count: Int
    let items: [SubscanRewardItemData]?
}

struct SubscanRewardItemData: Codable {
    enum CodingKeys: String, CodingKey {
        case recordId = "event_index"
        case blockNumber = "block_num"
        case extrinsicIndex = "extrinsic_idx"
        case extrinsicHash = "extrinsic_hash"
        case moduleId = "module_id"
        case params
        case eventId = "event_id"
        case eventIndex = "event_idx"
        case amount
        case timestamp = "block_timestamp"
    }

    let recordId: String
    let blockNumber: UInt64
    let extrinsicIndex: UInt16
    let extrinsicHash: String
    let moduleId: String
    let params: String
    let eventId: String
    let eventIndex: Int
    let amount: String
    let timestamp: Int64
}
