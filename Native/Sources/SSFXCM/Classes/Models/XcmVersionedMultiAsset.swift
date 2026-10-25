import Foundation

/// `VersionedAsset` (`VersionedMultiAsset` before V4). Runtimes no longer accept V1 or V2.
enum XcmVersionedMultiAsset: Codable {
    case V3(XcmV1MultiAsset)
    case V4(XcmV1MultiAsset)
    case V5(XcmV1MultiAsset)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .V3(multiasset):
            try container.encode("V3")
            try container.encode(multiasset)
        case let .V4(asset):
            try container.encode("V4")
            try container.encode(XcmArrayJunctionsAsset(asset: asset))
        case let .V5(asset):
            try container.encode("V5")
            try container.encode(XcmArrayJunctionsAsset(asset: asset))
        }
    }
}

extension XcmVersionedMultiAsset: Equatable {
    static func == (lhs: XcmVersionedMultiAsset, rhs: XcmVersionedMultiAsset) -> Bool {
        switch (lhs, rhs) {
        case let (.V3(lhsValue), .V3(rhsValue)):
            return lhsValue == rhsValue
        case let (.V4(lhsValue), .V4(rhsValue)):
            return lhsValue == rhsValue
        case let (.V5(lhsValue), .V5(rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}
