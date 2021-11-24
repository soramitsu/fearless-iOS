import Foundation

struct SubscanMemoData: Decodable {
    let count: Int
    let extrinsics: [SubscanMemoItemData]?
}

struct SubscanMemoItemData: Decodable {
    enum CodingKeys: String, CodingKey {
        case success
        case hash = "extrinsic_hash"
        case timestamp = "block_timestamp"
        case fee
        case blockNumber = "block_num"
        case finalized
        case extrinsicIndex = "extrinsic_index"
        case params
    }

    let success: Bool?
    let finalized: Bool?
    let hash: String
    let timestamp: Int64
    let fee: String
    let blockNumber: UInt64
    let extrinsicIndex: ExtrinisicIndexWrapper
    let params: String
}
