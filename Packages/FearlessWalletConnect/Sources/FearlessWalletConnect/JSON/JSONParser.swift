import Foundation

public enum JSONParseError: Error, Equatable {
    case tooLarge
    case tooDeep
    case unexpectedEnd
    case unexpectedByte(offset: Int)
    case invalidNumber(offset: Int)
    case invalidString(offset: Int)
    case duplicateKey(String)
    case trailingData(offset: Int)
}

/// A strict RFC 8259 parser for what peers and the relay send. It keeps numbers as their exact text, refuses
/// duplicate object keys (two readers could otherwise disagree on a value), lone surrogates and unescaped control
/// characters, and bounds the input size and nesting depth.
public struct JSONParser {
    public static let defaultMaxBytes = 4 * 1024 * 1024
    public static let defaultMaxDepth = 64

    private let bytes: [UInt8]
    private let maxDepth: Int
    private var index = 0

    public static func parse(
        _ data: Data,
        maxBytes: Int = defaultMaxBytes,
        maxDepth: Int = defaultMaxDepth
    ) throws -> JSONValue {
        guard data.count <= maxBytes else {
            throw JSONParseError.tooLarge
        }
        var parser = JSONParser(bytes: [UInt8](data), maxDepth: maxDepth)
        return try parser.parseDocument()
    }

    public static func parse(
        _ text: String,
        maxBytes: Int = defaultMaxBytes,
        maxDepth: Int = defaultMaxDepth
    ) throws -> JSONValue {
        try parse(Data(text.utf8), maxBytes: maxBytes, maxDepth: maxDepth)
    }

    private init(bytes: [UInt8], maxDepth: Int) {
        self.bytes = bytes
        self.maxDepth = maxDepth
    }

    private mutating func parseDocument() throws -> JSONValue {
        skipWhitespace()
        let value = try parseValue(depth: 0)
        skipWhitespace()
        guard index == bytes.count else {
            throw JSONParseError.trailingData(offset: index)
        }
        return value
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D:
                index += 1
            default:
                return
            }
        }
    }

    private func peek() throws -> UInt8 {
        guard index < bytes.count else {
            throw JSONParseError.unexpectedEnd
        }
        return bytes[index]
    }

    private mutating func expect(_ literal: [UInt8]) throws {
        guard index + literal.count <= bytes.count else {
            throw JSONParseError.unexpectedEnd
        }
        for (offset, byte) in literal.enumerated() where bytes[index + offset] != byte {
            throw JSONParseError.unexpectedByte(offset: index + offset)
        }
        index += literal.count
    }

    private mutating func parseValue(depth: Int) throws -> JSONValue {
        guard depth <= maxDepth else {
            throw JSONParseError.tooDeep
        }

        switch try peek() {
        case UInt8(ascii: "{"):
            return try parseObject(depth: depth + 1)
        case UInt8(ascii: "["):
            return try parseArray(depth: depth + 1)
        case UInt8(ascii: "\""):
            return .string(try parseString())
        case UInt8(ascii: "t"):
            try expect(Array("true".utf8))
            return .bool(true)
        case UInt8(ascii: "f"):
            try expect(Array("false".utf8))
            return .bool(false)
        case UInt8(ascii: "n"):
            try expect(Array("null".utf8))
            return .null
        case UInt8(ascii: "-"), UInt8(ascii: "0") ... UInt8(ascii: "9"):
            return .number(try parseNumber())
        default:
            throw JSONParseError.unexpectedByte(offset: index)
        }
    }

    private mutating func parseObject(depth: Int) throws -> JSONValue {
        guard depth <= maxDepth else {
            throw JSONParseError.tooDeep
        }
        index += 1
        var object: [String: JSONValue] = [:]
        skipWhitespace()

        if try peek() == UInt8(ascii: "}") {
            index += 1
            return .object(object)
        }

        while true {
            skipWhitespace()
            guard try peek() == UInt8(ascii: "\"") else {
                throw JSONParseError.unexpectedByte(offset: index)
            }
            let key = try parseString()
            skipWhitespace()
            guard try peek() == UInt8(ascii: ":") else {
                throw JSONParseError.unexpectedByte(offset: index)
            }
            index += 1
            skipWhitespace()
            let value = try parseValue(depth: depth)
            guard object[key] == nil else {
                throw JSONParseError.duplicateKey(key)
            }
            object[key] = value
            skipWhitespace()

            switch try peek() {
            case UInt8(ascii: ","):
                index += 1
            case UInt8(ascii: "}"):
                index += 1
                return .object(object)
            default:
                throw JSONParseError.unexpectedByte(offset: index)
            }
        }
    }

    private mutating func parseArray(depth: Int) throws -> JSONValue {
        guard depth <= maxDepth else {
            throw JSONParseError.tooDeep
        }
        index += 1
        var array: [JSONValue] = []
        skipWhitespace()

        if try peek() == UInt8(ascii: "]") {
            index += 1
            return .array(array)
        }

        while true {
            skipWhitespace()
            array.append(try parseValue(depth: depth))
            skipWhitespace()

            switch try peek() {
            case UInt8(ascii: ","):
                index += 1
            case UInt8(ascii: "]"):
                index += 1
                return .array(array)
            default:
                throw JSONParseError.unexpectedByte(offset: index)
            }
        }
    }

    private mutating func parseNumber() throws -> JSONNumber {
        let start = index
        while index < bytes.count, Self.isNumberByte(bytes[index]) {
            index += 1
        }

        let slice = Array(bytes[start ..< index])
        guard slice.count <= 1024, JSONNumber.isValid(slice), let text = String(bytes: slice, encoding: .utf8) else {
            throw JSONParseError.invalidNumber(offset: start)
        }
        return JSONNumber(validatedText: text)
    }

    private static func isNumberByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "0") ... UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "+"),
             UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"):
            return true
        default:
            return false
        }
    }

    private mutating func parseString() throws -> String {
        let start = index
        index += 1
        var output: [UInt8] = []

        while true {
            guard index < bytes.count else {
                throw JSONParseError.unexpectedEnd
            }
            let byte = bytes[index]

            switch byte {
            case UInt8(ascii: "\""):
                index += 1
                guard let string = String(bytes: output, encoding: .utf8) else {
                    throw JSONParseError.invalidString(offset: start)
                }
                return string
            case UInt8(ascii: "\\"):
                index += 1
                guard index < bytes.count else {
                    throw JSONParseError.unexpectedEnd
                }
                let escaped = bytes[index]
                index += 1
                switch escaped {
                case UInt8(ascii: "\""): output.append(0x22)
                case UInt8(ascii: "\\"): output.append(0x5C)
                case UInt8(ascii: "/"): output.append(0x2F)
                case UInt8(ascii: "b"): output.append(0x08)
                case UInt8(ascii: "f"): output.append(0x0C)
                case UInt8(ascii: "n"): output.append(0x0A)
                case UInt8(ascii: "r"): output.append(0x0D)
                case UInt8(ascii: "t"): output.append(0x09)
                case UInt8(ascii: "u"):
                    let scalar = try parseUnicodeEscape(start: start)
                    output.append(contentsOf: Array(String(Character(scalar)).utf8))
                default:
                    throw JSONParseError.invalidString(offset: index - 1)
                }
            case 0x00 ..< 0x20:
                throw JSONParseError.invalidString(offset: index)
            default:
                output.append(byte)
                index += 1
            }
        }
    }

    private mutating func parseHexQuad() throws -> UInt32 {
        guard index + 4 <= bytes.count else {
            throw JSONParseError.unexpectedEnd
        }
        var value: UInt32 = 0
        for _ in 0 ..< 4 {
            let byte = bytes[index]
            let nibble: UInt32
            switch byte {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                nibble = UInt32(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a") ... UInt8(ascii: "f"):
                nibble = UInt32(byte - UInt8(ascii: "a") + 10)
            case UInt8(ascii: "A") ... UInt8(ascii: "F"):
                nibble = UInt32(byte - UInt8(ascii: "A") + 10)
            default:
                throw JSONParseError.invalidString(offset: index)
            }
            value = value << 4 | nibble
            index += 1
        }
        return value
    }

    private mutating func parseUnicodeEscape(start: Int) throws -> Unicode.Scalar {
        let first = try parseHexQuad()

        if (0xD800 ... 0xDBFF).contains(first) {
            // A high surrogate must be followed by an escaped low surrogate.
            guard
                index + 2 <= bytes.count,
                bytes[index] == UInt8(ascii: "\\"),
                bytes[index + 1] == UInt8(ascii: "u")
            else {
                throw JSONParseError.invalidString(offset: start)
            }
            index += 2
            let second = try parseHexQuad()
            guard (0xDC00 ... 0xDFFF).contains(second) else {
                throw JSONParseError.invalidString(offset: start)
            }
            let combined = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
            guard let scalar = Unicode.Scalar(combined) else {
                throw JSONParseError.invalidString(offset: start)
            }
            return scalar
        }

        guard !(0xDC00 ... 0xDFFF).contains(first), let scalar = Unicode.Scalar(first) else {
            throw JSONParseError.invalidString(offset: start)
        }
        return scalar
    }
}
