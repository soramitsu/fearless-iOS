import Foundation

struct RuntimeDispatchInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case dispatchClass = "class"
        case fee = "partialFee"
        case weight
    }

    let dispatchClass: String
    let fee: String
    let weight: UInt64
}
