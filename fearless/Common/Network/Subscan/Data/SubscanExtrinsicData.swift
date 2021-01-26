import Foundation

struct SubscanExtrinsicData: Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case extrinsics
    }

    let count: Int
    let extrinsics: [SubscanItemExtrinsicData]?
}

struct SubscanItemExtrinsicData: Codable {
    enum CodingKeys: String, CodingKey {
        case blockTimestamp = "block_timestamp"
        case blockNumber = "block_num"
        case extrinsicIndex = "extrinsic_index"
        case callModule = "call_module"
        case callFunction = "call_module_function"
        case address = "account_id"
        case fee
        case extrinsicHash = "extrinsic_hash"
        case nonce
        case signature
        case accountIndex = "account_index"
        case success
        case finalized
    }

    let blockTimestamp: Int64
    let blockNumber: Int64
    let extrinsicIndex: String
    let callModule: String
    let callFunction: String
    let address: String
    let fee: String
    let extrinsicHash: String
    let nonce: Int
    let signature: String
    let accountIndex: String
    let success: Bool?
    let finalized: Bool?
}
