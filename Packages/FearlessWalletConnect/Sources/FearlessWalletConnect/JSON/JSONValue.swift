import Foundation

/// A JSON number kept as the exact text it arrived in, so that large integers and decimals from a peer are never
/// rounded through `Double` before the wallet decodes them into its own types.
public struct JSONNumber: Hashable, Sendable, CustomStringConvertible {
    public let text: String

    /// Accepts only the RFC 8259 number grammar.
    public init?(text: String) {
        guard JSONNumber.isValid(Array(text.utf8)) else {
            return nil
        }
        self.text = text
    }

    init(validatedText: String) {
        text = validatedText
    }

    public init(_ value: Int64) {
        text = String(value)
    }

    public init(_ value: UInt64) {
        text = String(value)
    }

    public init(_ value: Int) {
        text = String(value)
    }

    public var int64Value: Int64? {
        Int64(text)
    }

    public var uint64Value: UInt64? {
        UInt64(text)
    }

    public var doubleValue: Double? {
        Double(text)
    }

    public var description: String {
        text
    }

    static func isValid(_ bytes: [UInt8]) -> Bool {
        var index = 0
        let count = bytes.count

        func digit(_ position: Int) -> Bool {
            position < count && bytes[position] >= 0x30 && bytes[position] <= 0x39
        }

        if index < count, bytes[index] == 0x2D {
            index += 1
        }

        guard digit(index) else {
            return false
        }

        if bytes[index] == 0x30 {
            index += 1
        } else {
            while digit(index) {
                index += 1
            }
        }

        if index < count, bytes[index] == 0x2E {
            index += 1
            guard digit(index) else {
                return false
            }
            while digit(index) {
                index += 1
            }
        }

        if index < count, bytes[index] == 0x65 || bytes[index] == 0x45 {
            index += 1
            if index < count, bytes[index] == 0x2B || bytes[index] == 0x2D {
                index += 1
            }
            guard digit(index) else {
                return false
            }
            while digit(index) {
                index += 1
            }
        }

        return index == count
    }
}

/// A JSON value. Objects are unordered, as JSON defines them; serialization writes their keys sorted.
public enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case number(JSONNumber)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public subscript(key: String) -> JSONValue? {
        guard case let .object(object) = self else {
            return nil
        }
        return object[key]
    }

    public var objectValue: [String: JSONValue]? {
        guard case let .object(object) = self else {
            return nil
        }
        return object
    }

    public var arrayValue: [JSONValue]? {
        guard case let .array(array) = self else {
            return nil
        }
        return array
    }

    public var stringValue: String? {
        guard case let .string(string) = self else {
            return nil
        }
        return string
    }

    public var boolValue: Bool? {
        guard case let .bool(bool) = self else {
            return nil
        }
        return bool
    }

    public var numberValue: JSONNumber? {
        guard case let .number(number) = self else {
            return nil
        }
        return number
    }

    /// An integer that fits in `Int64`, written without a fraction or an exponent.
    public var int64Value: Int64? {
        numberValue?.int64Value
    }

    public var isNull: Bool {
        if case .null = self {
            return true
        }
        return false
    }

    public static func int(_ value: Int64) -> JSONValue {
        .number(JSONNumber(value))
    }

    public static func int(_ value: Int) -> JSONValue {
        .number(JSONNumber(value))
    }
}
