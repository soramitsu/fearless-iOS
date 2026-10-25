import Foundation
import SSFUtils

enum XcmV1MultiassetAssetId: Codable {
    case concrete(XcmV1MultiLocation)
    case abstract(Data)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .concrete(multilocation):
            try container.encode("Concrete")
            try container.encode(multilocation)
        case let .abstract(data):
            try container.encode("Abstract")
            try container.encode(BytesCodable(wrappedValue: data))
        }
    }
}

extension XcmV1MultiassetAssetId: Equatable {
    static func == (lhs: XcmV1MultiassetAssetId, rhs: XcmV1MultiassetAssetId) -> Bool {
        switch (lhs, rhs) {
        case let (.concrete(lhsValue), .concrete(rhsValue)):
            return lhsValue == rhsValue
        case let (.abstract(lhsValue), .abstract(rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}
