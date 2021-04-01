import Foundation

struct SubscanTransferData: Decodable {
    let count: Int
    let transfers: [SubscanTransferItemData]?
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
