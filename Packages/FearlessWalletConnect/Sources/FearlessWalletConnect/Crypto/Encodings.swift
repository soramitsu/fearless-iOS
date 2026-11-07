import Foundation

enum Hex {
    /// 32 bytes as 64 lowercase hex digits: a topic, a symmetric key or an X25519 public key.
    static func isKey(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (0x30 ... 0x39).contains($0) || (0x61 ... 0x66).contains($0) }
    }

    static func encode(_ data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var output = [UInt8]()
        output.reserveCapacity(data.count * 2)
        for byte in data {
            output.append(digits[Int(byte >> 4)])
            output.append(digits[Int(byte & 0x0F)])
        }
        return String(decoding: output, as: UTF8.self)
    }

    static func decode(_ string: String) -> Data? {
        let bytes = Array(string.utf8)
        guard bytes.count % 2 == 0 else {
            return nil
        }
        var output = Data(capacity: bytes.count / 2)
        var index = 0
        while index < bytes.count {
            guard let high = nibble(bytes[index]), let low = nibble(bytes[index + 1]) else {
                return nil
            }
            output.append(high << 4 | low)
            index += 2
        }
        return output
    }

    static func decodeKey(_ string: String) -> Data? {
        guard isKey(string) else {
            return nil
        }
        return decode(string)
    }

    private static func nibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30 ... 0x39:
            return byte - 0x30
        case 0x61 ... 0x66:
            return byte - 0x61 + 10
        case 0x41 ... 0x46:
            return byte - 0x41 + 10
        default:
            return nil
        }
    }
}

enum Base64 {
    /// Standard base64 with padding, as peers write envelopes.
    static func encode(_ data: Data) -> String {
        data.base64EncodedString()
    }

    /// Standard base64; the padding may be missing.
    static func decode(_ string: String) -> Data? {
        let bytes = Array(string.utf8)
        var padding = 0
        for byte in bytes.reversed() {
            guard byte == UInt8(ascii: "=") else {
                break
            }
            padding += 1
        }
        guard padding <= 2 else {
            return nil
        }
        let body = bytes.dropLast(padding)
        let isAlphabet = body.allSatisfy { byte in
            (0x41 ... 0x5A).contains(byte) || (0x61 ... 0x7A).contains(byte) || (0x30 ... 0x39).contains(byte)
                || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "/")
        }
        guard isAlphabet, body.count % 4 != 1 else {
            return nil
        }
        var padded = String(decoding: body, as: UTF8.self)
        while padded.utf8.count % 4 != 0 {
            padded += "="
        }
        if padding > 0, padded.utf8.count != bytes.count {
            return nil
        }
        return Data(base64Encoded: padded)
    }

    /// Base64url without padding, as JWTs use it.
    static func encodeURL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decodeURL(_ string: String) -> Data? {
        var trimmed = string
        while trimmed.hasSuffix("=") {
            trimmed.removeLast()
        }
        guard trimmed.utf8.allSatisfy({ byte in
            (0x41 ... 0x5A).contains(byte) || (0x61 ... 0x7A).contains(byte) || (0x30 ... 0x39).contains(byte)
                || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "_")
        }) else {
            return nil
        }
        let standard = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        return decode(standard)
    }
}

/// Bitcoin-alphabet base58, as did:key identifiers use it (multibase prefix `z`).
enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)

    static func encode(_ data: Data) -> String {
        let bytes = [UInt8](data)
        let zeros = bytes.prefix { $0 == 0 }.count
        // Base58 digits, least significant first.
        var digits: [UInt8] = []
        for byte in bytes {
            var carry = Int(byte)
            for index in digits.indices {
                carry += Int(digits[index]) << 8
                digits[index] = UInt8(carry % 58)
                carry /= 58
            }
            while carry > 0 {
                digits.append(UInt8(carry % 58))
                carry /= 58
            }
        }
        let leading = [UInt8](repeating: alphabet[0], count: zeros)
        let body = digits.reversed().map { alphabet[Int($0)] }
        return String(decoding: leading + body, as: UTF8.self)
    }

    static func decode(_ string: String) -> Data? {
        var bytes: [UInt8] = []
        let characters = Array(string.utf8)
        let zeros = characters.prefix { $0 == alphabet[0] }.count
        for character in characters {
            guard let value = alphabet.firstIndex(of: character) else {
                return nil
            }
            var carry = value
            for index in bytes.indices {
                carry += Int(bytes[index]) * 58
                bytes[index] = UInt8(carry & 0xFF)
                carry >>= 8
            }
            while carry > 0 {
                bytes.append(UInt8(carry & 0xFF))
                carry >>= 8
            }
        }
        // `bytes` holds the value's significant bytes, least significant first.
        return Data(repeating: 0, count: zeros) + Data(bytes.reversed())
    }
}
