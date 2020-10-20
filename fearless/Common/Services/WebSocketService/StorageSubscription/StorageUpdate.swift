import Foundation

struct StorageUpdate: Decodable {
    enum CodingKeys: String, CodingKey {
        case blockHash = "block"
        case changes
    }

    let blockHash: String?
    let changes: [[String?]]?
}
