import Foundation
import FearlessUtils

enum CrowdloanLastContribution: Equatable {
    static let neverField = "Never"
    static let preEndingField = "PreEnding"
    static let endingField = "Ending"

    case never
    case preEnding(value: UInt32)
    case ending(blockNumber: UInt32)
}

extension CrowdloanLastContribution: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.neverField:
            self = .never
        case Self.preEndingField:
            let intStr = try container.decode(String.self)
            guard let value = UInt32(intStr) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected int32 value"
                )
            }

            self = .preEnding(value: value)
        case Self.endingField:
            let intStr = try container.decode(String.self)
            guard let blockNumber = UInt32(intStr) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected blockNumber value"
                )
            }

            self = .ending(blockNumber: blockNumber)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .never:
            try container.encode(Self.neverField)
            try container.encode(JSON.null)
        case let .preEnding(value):
            try container.encode(Self.preEndingField)
            try container.encode(String(value))
        case let .ending(blockNumber):
            try container.encode(Self.endingField)
            try container.encode(String(blockNumber))
        }
    }
}
