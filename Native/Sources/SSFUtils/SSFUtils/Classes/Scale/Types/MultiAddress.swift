import BigInt
import Foundation

public enum MultiAddress: Equatable {
    static let accountIdField = "Id"
    static let indexField = "Index"
    static let rawField = "Raw"
    static let address32Field = "Address32"
    static let address20Field = "Address20"

    case accoundId(_ value: Data)
    case accountTo(_ value: Data)
    case accountIndex(_ value: BigUInt)
    case raw(_ value: Data)
    case address32(_ value: Data)
    case address20(_ value: Data)
    case indexedString(_ value: Data)
    case rawString(_ value: Data)
}

extension MultiAddress: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)

        switch type {
        case Self.accountIdField:
            let data = try container.decode(Data.self)
            self = .accoundId(data)
        case Self.indexField:
            let intStr = try container.decode(String.self)
            guard let value = BigUInt(intStr) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected big int value"
                )
            }

            self = .accountIndex(value)
        case Self.rawField:
            let data = try container.decode(Data.self)
            self = .raw(data)
        case Self.address32Field:
            let data = try container.decode(Data.self)
            self = .address32(data)
        case Self.address20Field:
            let data = try container.decode(Data.self)
            self = .address20(data)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .accoundId(value):
            var container = encoder.unkeyedContainer()
            try container.encode(Self.accountIdField)
            try container.encode(value)
        case let .accountIndex(value):
            var container = encoder.unkeyedContainer()
            try container.encode(Self.indexField)
            try container.encode(String(value))
        case let .raw(value):
            var container = encoder.unkeyedContainer()
            try container.encode(Self.rawField)
            try container.encode(value)
        case let .address32(value):
            var container = encoder.unkeyedContainer()
            try container.encode(Self.address32Field)
            try container.encode(value)
        case let .address20(value):
            var container = encoder.unkeyedContainer()
            try container.encode(Self.address20Field)
            try container.encode(value)
        case let .accountTo(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .indexedString(value):
            var container = encoder.singleValueContainer()
            let null = Data([0])
            let full = null + value
            try container.encode(full.toHex(includePrefix: true))
        case let .rawString(value):
            var container = encoder.singleValueContainer()
            try container.encode(value.toHex(includePrefix: true))
        }
    }
}
