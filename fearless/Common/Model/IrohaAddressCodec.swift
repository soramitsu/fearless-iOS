import Foundation

enum IrohaNetworkKind: String, Equatable {
    case taira
    case nexus
    case dev
    case custom
}

enum IrohaAddressErrorCode: String, Equatable {
    case invalidLength = "ERR_INVALID_LENGTH"
    case checksumMismatch = "ERR_CHECKSUM_MISMATCH"
    case invalidHexAddress = "ERR_INVALID_HEX_ADDRESS"
    case missingI105Sentinel = "ERR_MISSING_I105_SENTINEL"
    case i105TooShort = "ERR_I105_TOO_SHORT"
    case invalidI105Base = "ERR_INVALID_I105_BASE"
    case invalidI105Char = "ERR_INVALID_I105_CHAR"
    case invalidI105Digit = "ERR_INVALID_I105_DIGIT"
    case unsupportedAddressFormat = "ERR_UNSUPPORTED_ADDRESS_FORMAT"
    case unexpectedNetworkPrefix = "ERR_UNEXPECTED_NETWORK_PREFIX"
    case invalidI105Prefix = "ERR_INVALID_I105_PREFIX"
    case invalidHeaderVersion = "ERR_INVALID_HEADER_VERSION"
    case invalidNormVersion = "ERR_INVALID_NORM_VERSION"
    case unknownAddressClass = "ERR_UNKNOWN_ADDRESS_CLASS"
    case unexpectedExtensionFlag = "ERR_UNEXPECTED_EXTENSION_FLAG"
    case unknownControllerTag = "ERR_UNKNOWN_CONTROLLER_TAG"
    case unknownCurve = "ERR_UNKNOWN_CURVE"
    case unexpectedTrailingBytes = "ERR_UNEXPECTED_TRAILING_BYTES"
}

struct IrohaAddressError: Error, Equatable {
    let code: IrohaAddressErrorCode
}

struct IrohaAddressDetails: Equatable {
    let chainDiscriminant: Int
    let network: IrohaNetworkKind
    let canonicalHex: String
    let publicKeyHex: String
    let i105: String
}

enum IrohaAddressCodec {
    static let tairaDiscriminant = 369
    static let nexusDiscriminant = 753
    static let devDiscriminant = 0

    private static let i105DiscriminantMax = 0x3FFF
    private static let i105SentinelSora = "sora"
    private static let i105SentinelTest = "test"
    private static let i105SentinelDev = "dev"
    private static let i105SentinelFallbackPrefix = "n"
    private static let i105ChecksumLength = 6
    private static let i105Base = 105
    private static let bech32mConst: UInt32 = 0x2BC8_30A3
    private static let i105Hrp = "snx"
    private static let controllerSingleKeyTag: UInt8 = 0x00
    private static let curveEd25519: UInt8 = 0x01
    private static let ed25519PublicKeyLength = 32
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let irohaPoemKanaHalfwidth: [Character] = [
        "\u{ff72}",
        "\u{ff9b}",
        "\u{ff8a}",
        "\u{ff86}",
        "\u{ff8e}",
        "\u{ff8d}",
        "\u{ff84}",
        "\u{ff81}",
        "\u{ff98}",
        "\u{ff87}",
        "\u{ff99}",
        "\u{ff66}",
        "\u{ff9c}",
        "\u{ff76}",
        "\u{ff96}",
        "\u{ff80}",
        "\u{ff9a}",
        "\u{ff7f}",
        "\u{ff82}",
        "\u{ff88}",
        "\u{ff85}",
        "\u{ff97}",
        "\u{ff91}",
        "\u{ff73}",
        "\u{30f0}",
        "\u{ff89}",
        "\u{ff75}",
        "\u{ff78}",
        "\u{ff94}",
        "\u{ff8f}",
        "\u{ff79}",
        "\u{ff8c}",
        "\u{ff7a}",
        "\u{ff74}",
        "\u{ff83}",
        "\u{ff71}",
        "\u{ff7b}",
        "\u{ff77}",
        "\u{ff95}",
        "\u{ff92}",
        "\u{ff90}",
        "\u{ff7c}",
        "\u{30f1}",
        "\u{ff8b}",
        "\u{ff93}",
        "\u{ff7e}",
        "\u{ff7d}"
    ]
    private static let bech32Generators: [UInt32] = [0x3B6A_57B2, 0x2650_8E6D, 0x1EA1_19FA, 0x3D42_33DD, 0x2A14_62B3]

    private static var i105Alphabet: [Character] {
        base58Alphabet + irohaPoemKanaHalfwidth
    }

    private static var i105DigitTable: [Character: Int] {
        Dictionary(uniqueKeysWithValues: i105Alphabet.enumerated().map { ($0.element, $0.offset) })
    }

    static func canonicalHex(publicKeyHex: String) throws -> String {
        try publicKeyToCanonicalBytes(publicKeyHex: publicKeyHex).hexString()
    }

    static func encode(publicKeyHex: String, chainDiscriminant: Int) throws -> String {
        try encodeCanonicalHex(try canonicalHex(publicKeyHex: publicKeyHex), chainDiscriminant: chainDiscriminant)
    }

    static func encodeCanonicalHex(_ canonicalHex: String, chainDiscriminant: Int) throws -> String {
        try encodeI105Literal(
            chainDiscriminant: resolveDiscriminant(chainDiscriminant),
            canonicalBytes: normalizeHexBytes(canonicalHex)
        )
    }

    static func parse(_ address: String, expectedDiscriminant: Int? = nil) throws -> IrohaAddressDetails {
        if address.isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines) != address {
            throw IrohaAddressError(code: .unsupportedAddressFormat)
        }
        if address.hasPrefix("0x") || address.hasPrefix("0X") {
            throw IrohaAddressError(code: .unsupportedAddressFormat)
        }

        let decoded = try decodeI105Literal(address)
        let expected = try expectedDiscriminant.map(resolveDiscriminant)

        if let expected, decoded.chainDiscriminant != expected {
            throw IrohaAddressError(code: .unexpectedNetworkPrefix)
        }

        let publicKeyHex = try decodeCanonicalSingleEd25519(decoded.canonicalBytes)
        let i105 = try encodeI105Literal(chainDiscriminant: decoded.chainDiscriminant, canonicalBytes: decoded.canonicalBytes)

        if i105 != address {
            throw IrohaAddressError(code: .unsupportedAddressFormat)
        }

        return IrohaAddressDetails(
            chainDiscriminant: decoded.chainDiscriminant,
            network: networkFromDiscriminant(decoded.chainDiscriminant),
            canonicalHex: decoded.canonicalBytes.hexString(),
            publicKeyHex: publicKeyHex,
            i105: i105
        )
    }

    static func isValid(_ address: String, expectedDiscriminant: Int? = nil) -> Bool {
        (try? parse(address, expectedDiscriminant: expectedDiscriminant)) != nil
    }

    static func networkKind(_ address: String) -> IrohaNetworkKind? {
        (try? parse(address))?.network
    }

    private static func resolveDiscriminant(_ chainDiscriminant: Int) throws -> Int {
        guard (0 ... i105DiscriminantMax).contains(chainDiscriminant) else {
            throw IrohaAddressError(code: .invalidI105Prefix)
        }

        return chainDiscriminant
    }

    private static func networkFromDiscriminant(_ discriminant: Int) -> IrohaNetworkKind {
        switch discriminant {
        case UniversalWalletRegistry.taira.chainDiscriminant:
            return .taira
        case UniversalWalletRegistry.nexus.chainDiscriminant:
            return .nexus
        case devDiscriminant:
            return .dev
        default:
            return .custom
        }
    }

    private static func sentinelForDiscriminant(_ discriminant: Int) -> String {
        switch discriminant {
        case UniversalWalletRegistry.nexus.chainDiscriminant:
            return i105SentinelSora
        case UniversalWalletRegistry.taira.chainDiscriminant:
            return i105SentinelTest
        case devDiscriminant:
            return i105SentinelDev
        default:
            return "\(i105SentinelFallbackPrefix)\(discriminant)"
        }
    }

    private static func discriminantFromSentinel(_ input: String) -> Int? {
        if input.hasPrefix(i105SentinelSora) {
            return UniversalWalletRegistry.nexus.chainDiscriminant
        }
        if input.hasPrefix(i105SentinelTest) {
            return UniversalWalletRegistry.taira.chainDiscriminant
        }
        if input.hasPrefix(i105SentinelDev) {
            return devDiscriminant
        }
        guard input.hasPrefix(i105SentinelFallbackPrefix) else {
            return nil
        }

        let digits = input.dropFirst().prefix(5).prefix { isAsciiDigit($0) }
        guard !digits.isEmpty, let discriminant = Int(String(digits)), discriminant <= i105DiscriminantMax else {
            return nil
        }

        return discriminant
    }

    private static func encodeI105Literal(chainDiscriminant: Int, canonicalBytes: [UInt8]) throws -> String {
        let digits = try encodeBaseN(bytes: canonicalBytes, base: i105Base)
        let checksum = i105ChecksumDigits(canonicalBytes)

        return try ([sentinelForDiscriminant(chainDiscriminant)] + (digits + checksum).map { String(try i105DigitSymbol($0)) })
            .joined()
    }

    private static func decodeI105Literal(_ input: String) throws -> (chainDiscriminant: Int, canonicalBytes: [UInt8]) {
        guard let discriminant = discriminantFromSentinel(input) else {
            throw IrohaAddressError(code: .missingI105Sentinel)
        }

        let sentinel = sentinelForDiscriminant(discriminant)
        guard input.hasPrefix(sentinel) else {
            throw IrohaAddressError(code: .unsupportedAddressFormat)
        }

        return (discriminant, try decodeI105Payload(String(input.dropFirst(sentinel.count))))
    }

    private static func decodeI105Payload(_ payload: String) throws -> [UInt8] {
        let table = i105DigitTable
        let digits = try payload.map { character in
            guard let digit = table[character] else {
                throw IrohaAddressError(code: .invalidI105Char)
            }

            return digit
        }

        guard digits.count > i105ChecksumLength else {
            throw IrohaAddressError(code: .i105TooShort)
        }

        let splitAt = digits.count - i105ChecksumLength
        let canonicalBytes = try decodeBaseN(digits: Array(digits[..<splitAt]), base: i105Base)
        let expected = i105ChecksumDigits(canonicalBytes)

        guard Array(digits[splitAt...]) == expected else {
            throw IrohaAddressError(code: .checksumMismatch)
        }

        return canonicalBytes
    }

    private static func i105DigitSymbol(_ digit: Int) throws -> Character {
        guard i105Alphabet.indices.contains(digit) else {
            throw IrohaAddressError(code: .invalidI105Digit)
        }

        return i105Alphabet[digit]
    }

    private static func encodeBaseN(bytes: [UInt8], base: Int) throws -> [Int] {
        guard base >= 2 else {
            throw IrohaAddressError(code: .invalidI105Base)
        }
        guard !bytes.isEmpty else {
            return [0]
        }

        var value = bytes.map(Int.init)
        let leadingZeros = value.prefix { $0 == 0 }.count
        var digits: [Int] = []
        var start = leadingZeros

        while start < value.count {
            var remainder = 0

            for index in start ..< value.count {
                let accumulator = (remainder << 8) | value[index]
                value[index] = accumulator / base
                remainder = accumulator % base
            }

            digits.append(remainder)

            while start < value.count, value[start] == 0 {
                start += 1
            }
        }

        digits.append(contentsOf: Array(repeating: 0, count: leadingZeros))
        if digits.isEmpty {
            digits.append(0)
        }

        return Array(digits.reversed())
    }

    private static func decodeBaseN(digits: [Int], base: Int) throws -> [UInt8] {
        guard base >= 2 else {
            throw IrohaAddressError(code: .invalidI105Base)
        }
        guard !digits.isEmpty else {
            throw IrohaAddressError(code: .invalidLength)
        }

        var value = digits
        let leadingZeros = value.prefix { $0 == 0 }.count
        var bytes: [Int] = []
        var start = leadingZeros

        while start < value.count {
            var remainder = 0

            for index in start ..< value.count {
                let digit = value[index]
                guard digit < base else {
                    throw IrohaAddressError(code: .invalidI105Digit)
                }

                let accumulator = remainder * base + digit
                value[index] = accumulator / 256
                remainder = accumulator % 256
            }

            bytes.append(remainder)

            while start < value.count, value[start] == 0 {
                start += 1
            }
        }

        bytes.append(contentsOf: Array(repeating: 0, count: leadingZeros))
        return bytes.reversed().map(UInt8.init)
    }

    private static func i105ChecksumDigits(_ canonicalBytes: [UInt8]) -> [Int] {
        let data = convertToBase32(canonicalBytes)
        let values = expandHrp(i105Hrp) + data + Array(repeating: 0, count: i105ChecksumLength)
        let polymod = bech32Polymod(values) ^ bech32mConst

        return (0 ..< i105ChecksumLength).map { index in
            Int((polymod >> UInt32(5 * (i105ChecksumLength - 1 - index))) & 0x1F)
        }
    }

    private static func convertToBase32(_ bytes: [UInt8]) -> [Int] {
        var accumulator = 0
        var bits = 0
        var result: [Int] = []

        for byte in bytes {
            accumulator = ((accumulator << 8) | Int(byte)) & 0xFFF
            bits += 8

            while bits >= 5 {
                bits -= 5
                result.append((accumulator >> bits) & 0x1F)
            }
        }

        if bits > 0 {
            result.append((accumulator << (5 - bits)) & 0x1F)
        }

        return result
    }

    private static func bech32Polymod(_ values: [Int]) -> UInt32 {
        var checksum: UInt32 = 1

        for value in values {
            let top = checksum >> 25
            checksum = ((checksum & 0x1FFFFFF) << 5) ^ UInt32(value)

            for (index, generator) in bech32Generators.enumerated() where ((top >> UInt32(index)) & 1) == 1 {
                checksum ^= generator
            }
        }

        return checksum
    }

    private static func expandHrp(_ hrp: String) -> [Int] {
        hrp.utf8.map { Int($0 >> 5) } + [0] + hrp.utf8.map { Int($0 & 31) }
    }

    private static func decodeCanonicalSingleEd25519(_ canonicalBytes: [UInt8]) throws -> String {
        guard let header = canonicalBytes.first else {
            throw IrohaAddressError(code: .invalidLength)
        }

        let version = header >> 5
        let classBits = (header >> 3) & 0b11
        let normVersion = (header >> 1) & 0b11
        let extFlag = (header & 1) == 1

        if extFlag {
            throw IrohaAddressError(code: .unexpectedExtensionFlag)
        }
        if version != 0 {
            throw IrohaAddressError(code: .invalidHeaderVersion)
        }
        if normVersion != 1 {
            throw IrohaAddressError(code: .invalidNormVersion)
        }
        if classBits != 0 {
            throw IrohaAddressError(code: .unknownAddressClass)
        }
        guard canonicalBytes.count >= 4 else {
            throw IrohaAddressError(code: .invalidLength)
        }

        let tag = canonicalBytes[1]
        let curve = canonicalBytes[2]
        let length = Int(canonicalBytes[3])

        if tag != controllerSingleKeyTag {
            throw IrohaAddressError(code: .unknownControllerTag)
        }
        if curve != curveEd25519 {
            throw IrohaAddressError(code: .unknownCurve)
        }
        if length != ed25519PublicKeyLength {
            throw IrohaAddressError(code: .invalidLength)
        }
        if canonicalBytes.count < 4 + length {
            throw IrohaAddressError(code: .invalidLength)
        }
        if canonicalBytes.count != 4 + length {
            throw IrohaAddressError(code: .unexpectedTrailingBytes)
        }

        return String(Array(canonicalBytes[4 ..< (4 + length)]).hexString().dropFirst(2))
    }

    private static func publicKeyToCanonicalBytes(publicKeyHex: String) throws -> [UInt8] {
        let publicKey = try normalizeHexBytes(publicKeyHex, expectedBytes: ed25519PublicKeyLength)
        return [0x02, controllerSingleKeyTag, curveEd25519, UInt8(publicKey.count)] + publicKey
    }

    private static func normalizeHexBytes(_ value: String, expectedBytes: Int? = nil) throws -> [UInt8] {
        let hex = value.hasPrefix("0x") || value.hasPrefix("0X") ? String(value.dropFirst(2)) : value

        guard !hex.isEmpty, hex.count % 2 == 0, hex.range(of: "^[0-9a-fA-F]+$", options: .regularExpression) != nil else {
            throw IrohaAddressError(code: .invalidHexAddress)
        }
        if let expectedBytes, hex.count != expectedBytes * 2 {
            throw IrohaAddressError(code: .invalidLength)
        }

        var result: [UInt8] = []
        var index = hex.startIndex

        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(String(hex[index ..< next]), radix: 16) else {
                throw IrohaAddressError(code: .invalidHexAddress)
            }

            result.append(byte)
            index = next
        }

        return result
    }

    private static func isAsciiDigit(_ character: Character) -> Bool {
        character.unicodeScalars.count == 1 && character.unicodeScalars.first.map { (48 ... 57).contains(Int($0.value)) } == true
    }
}

private extension Array where Element == UInt8 {
    func hexString() -> String {
        "0x" + map { String(format: "%02x", $0) }.joined()
    }
}
