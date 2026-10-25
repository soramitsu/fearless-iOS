import BigInt
import Foundation

extension BigUInt: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(description, radix: 10)
    }
}

@propertyWrapper
public struct StringCodable<T: LosslessStringConvertible & Equatable>: Codable, Equatable {
    public var wrappedValue: T

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let strValue = try container.decode(String.self)

        guard let value = T(strValue) else {
            throw DecodingError
                .dataCorrupted(.init(codingPath: container.codingPath, debugDescription: ""))
        }

        wrappedValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue.description)
    }
}

@propertyWrapper
public struct OptionStringCodable<T: LosslessStringConvertible & Equatable>: Codable, Equatable {
    public var wrappedValue: T?

    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            wrappedValue = nil
        } else {
            let strValue = try container.decode(String.self)

            guard let value = T(strValue) else {
                wrappedValue = nil
                return
            }

            wrappedValue = value
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let value = wrappedValue?.description {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }
}

@propertyWrapper
public struct NullCodable<T: Codable>: Codable {
    public var wrappedValue: T?

    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            wrappedValue = nil
        } else {
            wrappedValue = try container.decode(T.self)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let value = wrappedValue {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }
}

extension NullCodable: Equatable where T: Equatable {}

@propertyWrapper
public struct BytesCodable: Codable, Equatable {
    public var wrappedValue: Data

    public init(wrappedValue: Data) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let byteArray = try container.decode([StringCodable<UInt8>].self)

        wrappedValue = Data(byteArray.map(\.wrappedValue))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let bytes = wrappedValue.map { StringCodable(wrappedValue: $0) }

        try container.encode(bytes)
    }
}

@propertyWrapper
public struct ArrayCodable: Codable, Equatable {
    public var wrappedValue: String

    public init(wrappedValue: String) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let byteArray = try container.decode([StringScaleMapper<UInt8>].self)
        let value = byteArray.reduce("0x") { $0 + String(format: "%02x", $1.value) }

        wrappedValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        guard let bytes = try? Data(hexStringSSF: wrappedValue)
            .map({ StringScaleMapper(value: $0) }) else
        {
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Invalid encoding"
            )
            throw EncodingError.invalidValue(wrappedValue, context)
        }

        try container.encode(bytes)
    }
}
