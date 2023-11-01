import Foundation

struct AddRemarkCall: Codable {
    @BytesCodable var remark: Data

    enum CodingKeys: String, CodingKey {
        case remark
    }
}
