import BigInt
import Foundation
import SSFUtils

/// `WeightLimit` of XCM V3, which V4 and V5 keep. The `Limited(u64)` form of V2 is gone.
enum XcmWeightLimit: Codable {
    case unlimited
    case limitedV3(weight: SpWeightsWeightV3Weight)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .unlimited:
            try container.encode("Unlimited")
            try container.encode(JSON.null)
        case let .limitedV3(weight):
            try container.encode("Limited")
            try container.encode(weight)
        }
    }

    init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "XcmWeightLimit is only ever encoded"
        ))
    }
}

extension XcmWeightLimit: Equatable {
    static func == (lhs: XcmWeightLimit, rhs: XcmWeightLimit) -> Bool {
        switch (lhs, rhs) {
        case let (.limitedV3(lhsValue), .limitedV3(rhsValue)):
            return lhsValue == rhsValue
        case (.unlimited, .unlimited):
            return true
        default:
            return false
        }
    }
}
