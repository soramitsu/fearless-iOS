import Foundation

/// Any JSON a peer sent or the wallet answers with: a method's parameters or a result.
///
/// Values the wallet wraps are encoded with `JSONEncoder`'s default strategies and decoded back with
/// `JSONDecoder`'s, so `AnyCodable(data).get(Data.self)` returns the same bytes.
public struct AnyCodable: Hashable, Sendable, CustomStringConvertible {
    public let value: JSONValue

    public init(json: JSONValue) {
        value = json
    }

    /// Wraps an encodable value as the JSON `JSONEncoder` writes for it. A value that cannot be encoded (for
    /// example a non-finite floating point number) becomes `null`.
    public init<T: Encodable>(_ encodable: T) {
        if let json = encodable as? JSONValue {
            value = json
            return
        }

        if let anyCodable = encodable as? AnyCodable {
            value = anyCodable.value
            return
        }

        do {
            let data = try JSONEncoder().encode(encodable)
            value = try JSONParser.parse(data)
        } catch {
            value = .null
        }
    }

    public static let null = AnyCodable(json: .null)

    /// Decodes the value into a type of the wallet.
    public func get<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerializer.data(from: value))
    }

    /// The value as compact JSON.
    public var stringRepresentation: String {
        JSONSerializer.string(from: value)
    }

    public var description: String {
        stringRepresentation
    }
}

extension AnyCodable: Codable {
    public init(from decoder: Decoder) throws {
        value = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

extension JSONValue: Codable {
    private struct Key: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: Key.self) {
            var object: [String: JSONValue] = [:]
            for key in container.allKeys {
                object[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        if var container = try? decoder.unkeyedContainer() {
            var array: [JSONValue] = []
            while !container.isAtEnd {
                array.append(try container.decode(JSONValue.self))
            }
            self = .array(array)
            return
        }

        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int64.self) {
            self = .number(JSONNumber(int))
        } else if let uint = try? container.decode(UInt64.self) {
            self = .number(JSONNumber(uint))
        } else if let double = try? container.decode(Double.self) {
            guard double.isFinite, let number = JSONNumber(text: String(double)) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Non-finite number")
            }
            self = .number(number)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .bool(bool):
            var container = encoder.singleValueContainer()
            try container.encode(bool)
        case let .number(number):
            var container = encoder.singleValueContainer()
            if let int = number.int64Value {
                try container.encode(int)
            } else if let uint = number.uint64Value {
                try container.encode(uint)
            } else if let decimal = Decimal(string: number.text, locale: Locale(identifier: "en_US_POSIX")) {
                try container.encode(decimal)
            } else {
                try container.encode(number.doubleValue ?? 0)
            }
        case let .string(string):
            var container = encoder.singleValueContainer()
            try container.encode(string)
        case let .array(array):
            var container = encoder.unkeyedContainer()
            for element in array {
                try container.encode(element)
            }
        case let .object(object):
            var container = encoder.container(keyedBy: Key.self)
            for key in object.keys.sorted() {
                try container.encode(object[key] ?? .null, forKey: Key(stringValue: key))
            }
        }
    }
}
