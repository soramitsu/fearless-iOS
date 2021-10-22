import Foundation

struct MoonbeamVerifyRemarkData: Decodable {
    let address: String
    let extrinsicHash: String
    let blockHash: String
    let verified: Bool
}
