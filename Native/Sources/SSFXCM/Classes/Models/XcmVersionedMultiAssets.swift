import Foundation

/// `VersionedAssets` (`VersionedMultiAssets` before V4). Runtimes no longer accept V1 or V2.
enum XcmVersionedMultiAssets: Codable {
    case V3([XcmV1MultiAsset])
    case V4([XcmV1MultiAsset])
    case V5([XcmV1MultiAsset])

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .V3(multiassets):
            try container.encode("V3")
            try container.encode(multiassets)
        case let .V4(assets):
            try container.encode("V4")
            try container.encode(assets.map { XcmArrayJunctionsAsset(asset: $0) })
        case let .V5(assets):
            try container.encode("V5")
            try container.encode(assets.map { XcmArrayJunctionsAsset(asset: $0) })
        }
    }
}

extension XcmVersionedMultiAssets: Equatable {
    static func == (lhs: XcmVersionedMultiAssets, rhs: XcmVersionedMultiAssets) -> Bool {
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
