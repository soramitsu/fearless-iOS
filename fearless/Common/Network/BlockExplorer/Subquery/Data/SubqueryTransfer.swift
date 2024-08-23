import Foundation

struct SubqueryTransfer: Decodable {
    enum CodingKeys: String, CodingKey {
        case amount
        case receiver = "to"
        case sender = "from"
        case fee
        case block
        case extrinsicId
        case extrinsicHash
        case success
        case assetId
    }

    let amount: String
    let receiver: String
    let sender: String
    let fee: String?
    let block: String?
    let extrinsicId: String?
    let extrinsicHash: String?
    let success: Bool
    let assetId: String?
}
