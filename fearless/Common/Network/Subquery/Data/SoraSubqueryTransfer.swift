import Foundation

struct SoraSubqueryTransfer: Decodable {
    enum CodingKeys: String, CodingKey {
        case amount
        case receiver = "to"
        case sender = "from"
        case assetId
        case extrinsicId
        case extrinsicHash
    }

    let amount: String
    let receiver: String
    let sender: String
    let assetId: String
    let extrinsicId: String?
    let extrinsicHash: String?
}
