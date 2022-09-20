import Foundation

struct FeeBlockWeight: Codable {
    enum CodingKeys: String, CodingKey {
        case refTime = "ref_time"
    }

    let refTime: UInt64
}

struct RuntimeDispatchInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case dispatchClass = "class"
        case fee = "partialFee"
        case weight
    }

    let dispatchClass: String
    let fee: String
    let weight: UInt64

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        dispatchClass = try container.decode(String.self, forKey: .dispatchClass)
        fee = try container.decode(String.self, forKey: .fee)

        let weight = try? container.decode(UInt64.self, forKey: .weight)
        let feeBlockWeight = try? container.decode(FeeBlockWeight.self, forKey: .weight)

        if let weight = weight {
            self.weight = weight
        } else if weight == nil, let blockWeight = feeBlockWeight?.refTime {
            self.weight = blockWeight
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .weight,
                in: container,
                debugDescription: "Fee block weight not found"
            )
        }
    }
}
