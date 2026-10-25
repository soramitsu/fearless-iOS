import Foundation

/// `VersionedLocation` (`VersionedMultiLocation` before V4). Runtimes no longer accept V1 or V2.
enum XcmVersionedMultiLocation: Codable {
    case V3(XcmV1MultiLocation)
    case V4(XcmV1MultiLocation)
    case V5(XcmV1MultiLocation)

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .V3(multilocation):
            try container.encode("V3")
            try container.encode(multilocation)
        case let .V4(location):
            try container.encode("V4")
            try container.encode(XcmArrayJunctionsLocation(location: location))
        case let .V5(location):
            try container.encode("V5")
            try container.encode(XcmArrayJunctionsLocation(location: location))
        }
    }
}

extension XcmVersionedMultiLocation: Equatable {
    static func == (lhs: XcmVersionedMultiLocation, rhs: XcmVersionedMultiLocation) -> Bool {
        switch (lhs, rhs) {
        case let (.V3(lhsMultilocation), .V3(rhsMultilocation)):
            return lhsMultilocation == rhsMultilocation
        case let (.V4(lhsLocation), .V4(rhsLocation)):
            return lhsLocation == rhsLocation
        case let (.V5(lhsLocation), .V5(rhsLocation)):
            return lhsLocation == rhsLocation
        default:
            return false
        }
    }
}
