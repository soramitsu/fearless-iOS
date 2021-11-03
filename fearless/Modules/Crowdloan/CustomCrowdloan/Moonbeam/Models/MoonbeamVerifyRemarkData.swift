import Foundation

struct MoonbeamVerifyRemarkData: Decodable {
    let address: String
    let extrinsicHash: String
    let blockHash: String
    let verified: Bool

    enum CodingKeys: String, CodingKey {
        case address
        case extrinsicHash = "extrinsic-hash"
        case blockHash = "block-hash"
        case verified
    }
}
