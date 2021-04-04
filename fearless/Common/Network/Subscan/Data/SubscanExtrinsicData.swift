import Foundation

struct SubscanExtrinsicData: Decodable {
    let count: Int
    let extrinsics: [SubscanExtrinsicItemData]?
}

struct SubscanExtrinsicItemData: Decodable {
    enum CodingKeys: String, CodingKey {
        case hash = "extrinsic_hash"
        case timestamp = "block_timestamp"
        case fee
        case blockNumber = "block_num"
        case extrinsicIndex = "extrinsic_index"
        case success
        case params
        case callModule = "call_module"
        case callFunction = "call_module_function"
    }

    let hash: String
    let timestamp: Int64
    let fee: String
    let blockNumber: UInt64
    let extrinsicIndex: ExtrinisicIndexWrapper
    let success: Bool?
    let params: String
    let callModule: String
    let callFunction: String
}
