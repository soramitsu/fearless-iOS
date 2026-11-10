import BigInt
import Foundation

/// Typed data values as the wallet shows them and signs them. Every value of an atomic declared type, in the domain
/// and at any depth of the message, is parsed strictly and written back in one canonical form before anything is
/// hashed or shown:
///
/// - `uintN` and `intN`: a decimal string without leading zeros (a `-` only for a signed type), a `0x` hex string, or
///   a JSON integer, within the type's bit width; written back as decimal text.
/// - `address`: `0x` and 40 hex digits.
/// - `bool`: a JSON `true` or `false`, or the numbers 1 and 0; written back as a JSON bool.
/// - `bytes`: `0x` and an even number of hex digits. `bytesN`: at most N bytes, written back right-padded to N.
/// - `string`: a JSON string.
///
/// The ABI encoder that hashes typed data is lenient: it reads `"ff"` as 255, `"1e18"` as 0x1e18, and `"-1"` or `-1`
/// for a `uint256` as 2^256 - 1, and it hashes a malformed address as whatever bytes it makes of it. After this pass it
/// only ever reads the canonical text, so the signature covers exactly the value the confirmation shows. A value the
/// encoder could read in another way is declined.
enum WalletConnectTypedDataValues {
    enum Problem: Error, Equatable {
        case invalidValue(path: String)
        case unsupportedType(path: String)
        case tooDeep
    }

    /// The object with each declared field's value made canonical. Keys the type does not declare are left as they
    /// are: the hash does not read them.
    static func canonical(
        object: [String: Any],
        type: String,
        path: String,
        types: MessageTypes,
        depth: Int = 0
    ) throws -> [String: Any] {
        guard let properties = types[type] else {
            throw Problem.unsupportedType(path: path)
        }
        guard depth <= WalletConnectTypedDataFields.maxDepth else {
            throw Problem.tooDeep
        }
        var result = object
        for property in properties {
            guard let value = object[property.name] else {
                continue
            }
            result[property.name] = try canonical(
                value: value,
                type: property.type,
                path: "\(path).\(property.name)",
                types: types,
                depth: depth + 1
            )
        }
        return result
    }

    static func canonical(value: Any, type: String, path: String, types: MessageTypes, depth: Int) throws -> Any {
        guard depth <= WalletConnectTypedDataFields.maxDepth else {
            throw Problem.tooDeep
        }

        if type.hasSuffix("]"), let bracket = type.lastIndex(of: "[") {
            guard let items = value as? [Any] else {
                throw Problem.invalidValue(path: path)
            }
            let size = type[type.index(after: bracket) ..< type.index(before: type.endIndex)]
            if !size.isEmpty {
                // A fixed-size array must have exactly its size.
                guard let count = Int(size), count == items.count else {
                    throw Problem.invalidValue(path: path)
                }
            }
            let itemType = String(type[..<bracket])
            return try items.enumerated().map { index, item in
                try canonical(value: item, type: itemType, path: "\(path)[\(index)]", types: types, depth: depth + 1)
            }
        }

        if types[type] != nil {
            guard let nested = value as? [String: Any] else {
                throw Problem.invalidValue(path: path)
            }
            return try canonical(object: nested, type: type, path: path, types: types, depth: depth)
        }

        return try atomic(value, type: type, path: path)
    }

    // MARK: - Atomic values

    static func atomic(_ value: Any, type: String, path: String) throws -> Any {
        if let bits = integerBits(type, prefix: "uint") {
            guard let number = integer(value), number.sign == .plus || number.isZero, number.magnitude.bitWidth <= bits else {
                throw Problem.invalidValue(path: path)
            }
            return String(number)
        }

        if let bits = integerBits(type, prefix: "int") {
            let limit = BigInt(1) << (bits - 1)
            guard let number = integer(value), number >= -limit, number < limit else {
                throw Problem.invalidValue(path: path)
            }
            return String(number)
        }

        switch type {
        case "address":
            guard let text = value as? String, let digits = hexDigits(text), digits.count == 40 else {
                throw Problem.invalidValue(path: path)
            }
            return text
        case "bool":
            guard let flag = WalletConnectTokenAllowance.bool(from: value as AnyObject) else {
                throw Problem.invalidValue(path: path)
            }
            return NSNumber(value: flag)
        case "string":
            guard let text = value as? String else {
                throw Problem.invalidValue(path: path)
            }
            return text
        case "bytes":
            guard let text = value as? String, let digits = hexDigits(text), digits.count.isMultiple(of: 2) else {
                throw Problem.invalidValue(path: path)
            }
            return text
        default:
            guard type.hasPrefix("bytes"), let length = Int(type.dropFirst(5)), (1 ... 32).contains(length) else {
                throw Problem.unsupportedType(path: path)
            }
            guard
                let text = value as? String,
                let digits = hexDigits(text),
                digits.count.isMultiple(of: 2),
                digits.count <= length * 2
            else {
                throw Problem.invalidValue(path: path)
            }
            // The hash pads a short value with zero bytes on the right: shown as it is hashed.
            return "0x" + digits.lowercased() + String(repeating: "0", count: length * 2 - digits.count)
        }
    }

    /// A canonical decimal ("0", "16", "-5"), a `0x` hex string ("0x10"), or a JSON integer; nothing else. The sign
    /// and the bit width are checked by the caller.
    static func integer(_ value: Any) -> BigInt? {
        if let text = value as? String {
            if text.hasPrefix("0x") {
                guard let digits = hexDigits(text), !digits.isEmpty else {
                    return nil
                }
                return BigInt(digits, radix: 16)
            }
            let negative = text.hasPrefix("-")
            let digits = negative ? String(text.dropFirst()) : text
            guard
                let first = digits.first,
                digits.allSatisfy({ $0.isASCII && $0.isNumber }),
                digits.count == 1 || first != "0",
                !(negative && digits == "0")
            else {
                return nil
            }
            return BigInt(text, radix: 10)
        }

        guard
            let number = value as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID(),
            !(number is NSDecimalNumber),
            !CFNumberIsFloatType(number as CFNumber)
        else {
            return nil
        }
        return BigInt(number.stringValue, radix: 10)
    }

    /// The bit width of `uintN` / `intN` (`uint` and `int` are 256); nil for any other type or an invalid width.
    static func integerBits(_ type: String, prefix: String) -> Int? {
        guard type.hasPrefix(prefix) else {
            return nil
        }
        let width = type.dropFirst(prefix.count)
        if width.isEmpty {
            return 256
        }
        guard
            width.allSatisfy({ $0.isASCII && $0.isNumber }),
            width.first != "0",
            let bits = Int(width),
            (8 ... 256).contains(bits),
            bits.isMultiple(of: 8)
        else {
            return nil
        }
        return bits
    }

    /// The hex digits after a `0x` prefix, when every one is an ASCII hex digit.
    private static func hexDigits(_ text: String) -> String? {
        guard text.hasPrefix("0x") else {
            return nil
        }
        let digits = String(text.dropFirst(2))
        guard digits.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            return nil
        }
        return digits
    }
}
