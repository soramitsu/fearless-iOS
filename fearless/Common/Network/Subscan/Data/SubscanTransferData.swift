import Foundation

struct SubscanTransferData: Decodable {
    let count: Int
    let transfers: [SubscanTransferItemData]?
}

struct ExtrinisicIndexValue: Decodable {
    let value: UInt16

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        guard let decodedIndexString = try container.decode(String.self).components(separatedBy: "-").last,
              let index = UInt16(decodedIndexString)
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unexpected index")
        }

        value = index
    }
}

struct SubscanTransferItemData: Decodable {
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
        case extrinsicIndex = "extrinsic_index"
    }

    let sender: String
    let receiver: String
    let success: Bool?
    let finalized: Bool?
    let hash: String
    let timestamp: Int64
    let amount: String
    let fee: String
    let blockNumber: UInt64
    let extrinsicIndex: ExtrinisicIndexValue
}
