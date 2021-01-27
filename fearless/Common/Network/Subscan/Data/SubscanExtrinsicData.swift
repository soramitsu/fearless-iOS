import Foundation

struct SubscanExtrinsicData: Codable {
    enum CodingKeys: String, CodingKey {
        case count
        case extrinsics
    }

    let count: Int
    let extrinsics: [SubscanExtrinsicItemData]?
}

struct SubscanExtrinsicItemData: Codable {
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
        case params
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
    let params: SubscanExtrinsicParams?
}

struct SubscanExtrinsicParams: Codable {
    let nodes: JSON

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let jsonString = try container.decode(String.self)

        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unexpected data")
        }

        nodes = try JSONDecoder().decode(JSON.self, from: data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        let data = try JSONEncoder().encode(nodes)

        if let string = String(data: data, encoding: .utf8) {
            try container.encode(string)
        }
    }
}
