import Foundation

/// Writes JSON compactly, with object keys sorted, so the same value always gives the same bytes.
public enum JSONSerializer {
    public static func string(from value: JSONValue) -> String {
        var output = ""
        write(value, into: &output)
        return output
    }

    public static func data(from value: JSONValue) -> Data {
        Data(string(from: value).utf8)
    }

    static func write(_ value: JSONValue, into output: inout String) {
        switch value {
        case .null:
            output += "null"
        case let .bool(bool):
            output += bool ? "true" : "false"
        case let .number(number):
            output += number.text
        case let .string(string):
            writeString(string, into: &output)
        case let .array(array):
            output += "["
            for (index, element) in array.enumerated() {
                if index > 0 {
                    output += ","
                }
                write(element, into: &output)
            }
            output += "]"
        case let .object(object):
            output += "{"
            for (index, key) in object.keys.sorted().enumerated() {
                if index > 0 {
                    output += ","
                }
                writeString(key, into: &output)
                output += ":"
                // The key comes from the dictionary itself.
                write(object[key] ?? .null, into: &output)
            }
            output += "}"
        }
    }

    /// A JSON string literal: quotes, backslashes and control characters escaped, everything else as is.
    public static func quoted(_ string: String) -> String {
        var output = ""
        writeString(string, into: &output)
        return output
    }

    static func writeString(_ string: String, into output: inout String) {
        output += "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"":
                output += "\\\""
            case "\\":
                output += "\\\\"
            case "\n":
                output += "\\n"
            case "\r":
                output += "\\r"
            case "\t":
                output += "\\t"
            case "\u{08}":
                output += "\\b"
            case "\u{0C}":
                output += "\\f"
            default:
                if scalar.value < 0x20 {
                    output += String(format: "\\u%04x", scalar.value)
                } else {
                    output.unicodeScalars.append(scalar)
                }
            }
        }
        output += "\""
    }
}
