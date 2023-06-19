import Foundation
import SSFUtils
import BigInt

public struct AssetDetailsV1: Decodable {
    @StringCodable public var minBalance: BigUInt
    public let isFrozen: Bool
    public let isSufficient: Bool
}

public struct AssetDetailsV2: Decodable {
    public enum Status: String, Decodable {
        case live = "Live"
        case frozen = "Frozen"
        case destroying = "Destroying"

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            guard let value = Status(rawValue: type) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected asset status"
                )
            }

            self = value
        }
    }

    @StringCodable public var minBalance: BigUInt
    public let status: Status
    public let isSufficient: Bool
}

public struct AssetDetails: Decodable {
    public let minBalance: BigUInt
    public let status: AssetDetailsV2.Status
    public let isSufficient: Bool

    public var isFrozen: Bool {
        status != .live
    }

    public init(from decoder: Decoder) throws {
        if let detailsV2 = try? AssetDetailsV2(from: decoder) {
            minBalance = detailsV2.minBalance
            status = detailsV2.status
            isSufficient = detailsV2.isSufficient
        } else {
            let detailsV1 = try AssetDetailsV1(from: decoder)

            minBalance = detailsV1.minBalance
            status = detailsV1.isFrozen ? .frozen : .live
            isSufficient = detailsV1.isSufficient
        }
    }
}
