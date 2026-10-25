import Foundation
import SSFUtils

struct XcmV1MultilocationJunctions: Codable {
    let items: [XcmJunction]

    /// V1 and V3 shape: `X1` holds a bare junction, `X2` to `X8` hold one value per junction.
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        if items.isEmpty {
            try container.encode("Here")
        } else {
            let xLocation = "X\(items.count)"
            try container.encode(xLocation)
        }

        if items.isEmpty {
            try container.encode(JSON.null)
        } else if items.count == 1 {
            try container.encode(items[0])
        } else {
            try container.encode(items)
        }
    }
}

extension XcmV1MultilocationJunctions: Equatable {}

/// V4 and V5 shape of the same junctions: `X1` to `X8` hold an array of junctions, also for one.
struct XcmArrayJunctions: Encodable {
    let items: [XcmJunction]

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        if items.isEmpty {
            try container.encode("Here")
            try container.encode(JSON.null)
        } else {
            try container.encode("X\(items.count)")
            try container.encode(items)
        }
    }
}

/// A V4 or V5 `Location`.
struct XcmArrayJunctionsLocation: Encodable {
    enum CodingKeys: String, CodingKey {
        case parents
        case interior
    }

    let location: XcmV1MultiLocation

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(location.parents), forKey: .parents)
        try container.encode(XcmArrayJunctions(items: location.interior.items), forKey: .interior)
    }
}

/// A V4 or V5 `Asset`: its id is the location itself, without V3's `Concrete` wrapper.
struct XcmArrayJunctionsAsset: Encodable {
    enum CodingKeys: String, CodingKey {
        case id
        case fun
    }

    let asset: XcmV1MultiAsset

    func encode(to encoder: Encoder) throws {
        guard case let .concrete(location) = asset.assetId else {
            throw EncodingError.invalidValue(asset, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "XCM V4 and later have no abstract asset ids"
            ))
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(XcmArrayJunctionsLocation(location: location), forKey: .id)
        try container.encode(asset.fun, forKey: .fun)
    }
}
