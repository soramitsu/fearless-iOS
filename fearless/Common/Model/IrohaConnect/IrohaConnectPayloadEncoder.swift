import BigInt
import Foundation

/// Encodes a reviewed transaction again with the canonical rules of the iroha-js 0.0.3 browser transaction
/// codec (`buildBrowserTransferPayload` / `buildBrowserExecutableBatchPayload`), including the input checks
/// those builders apply. A payload is signed only when this rebuild reproduces it byte for byte.
enum IrohaPayloadEncoder {
    enum Failure: Error, Equatable {
        case notCanonical(String)
    }

    typealias Reviewer = IrohaConnectTransactionReviewer

    /// `iroha.transfer` frame schema hash and compact-length flag of the SDK's transfer frames.
    static let transferSchemaHash = Data([
        0xA4, 0x17, 0x4C, 0x78, 0xD6, 0x34, 0x1F, 0x8F, 0x98, 0xFC, 0x2A, 0xDA, 0xE8, 0xED, 0x67, 0xB9
    ])
    static let compactLengthFlag: UInt8 = 0x02
    static let defaultTTLMs: UInt64 = 100_000
    private static let legacyFeeMetadataKeys: Set<String> = ["fee_sponsor", "gas_limit", "gas_asset_id"]
    private static let maximumNumericBits = 511
    private static let maximumContractEntrypointBytes = 1024
    private static let maximumContractArgumentBytes = 1024 * 1024

    static func payload(
        networkID: Data,
        authority: Reviewer.Account,
        creationTimeMs: UInt64,
        executable: Reviewer.Executable,
        ttlMs: UInt64?,
        nonce: UInt64?,
        fee: Reviewer.Fee,
        metadata: [(key: String, json: String)]
    ) throws -> Data {
        let executableArchive: Data
        switch executable {
        case let .transfer(sourceOwner, definition, _, scope, quantity, destination):
            guard sourceOwner.literal == authority.literal else {
                throw Failure.notCanonical(
                    "authority_mismatch: transparent browser transfers require the source asset owner to equal authority"
                )
            }
            try checkQuantity(quantity, label: "quantity")
            executableArchive = u32(0) + field(vector([transferInstruction(
                owner: sourceOwner,
                definition: definition,
                scope: scope,
                quantity: quantity,
                destination: destination
            )]))
        case let .contractCalls(calls):
            guard fee.gasLimit != nil else {
                throw Failure.notCanonical("invalid_fee_payment: feePayment.gasLimit is required when entries contain a contract call")
            }
            executableArchive = u32(4) + field(vector(try calls.enumerated().map { index, call in
                try checkContractCall(call, label: "entries[\(index)]")
                return u32(1) + field(contractInvocation(call))
            }))
        }
        try checkFee(fee)
        let ttl = ttlMs ?? defaultTTLMs
        guard ttl != 0 else {
            throw Failure.notCanonical("invalid_integer: ttlMs must be non-zero when provided")
        }
        if let nonce, nonce == 0 {
            throw Failure.notCanonical("invalid_integer: nonce must be non-zero when provided")
        }
        let metadataArchive = try IrohaMetadataJSON.canonicalArchive(metadata, legacyKeys: legacyFeeMetadataKeys)

        return structure([
            u32(0) + field(networkID),
            account(authority),
            u64(creationTimeMs),
            executableArchive,
            option(u64(ttl)),
            option(nonce.map { u32(UInt32(truncatingIfNeeded: $0)) }),
            feeArchive(fee),
            metadataArchive,
            Data([0])
        ])
    }

    // MARK: - Checks the SDK builders apply

    private static func checkQuantity(_ quantity: Reviewer.Quantity, label: String) throws {
        guard quantity.mantissa > 0 else {
            throw Failure.notCanonical("invalid_quantity: \(label) must be greater than zero")
        }
        guard quantity.mantissa.bitWidth - quantity.mantissa.leadingZeroBitCount <= maximumNumericBits else {
            throw Failure.notCanonical("bounds_exceeded: \(label) is outside the bounded Kotodama V1 domain")
        }
        if quantity.scale > 0, quantity.mantissa % 10 == 0 {
            throw Failure.notCanonical("invalid_quantity: \(label) must be canonical and non-negative (trailing_zero)")
        }
    }

    private static func checkFee(_ fee: Reviewer.Fee) throws {
        var previous: Int64 = -1
        for (index, limit) in fee.chargeLimits.enumerated() {
            guard Int64(limit.kindTag) > previous else {
                throw Failure.notCanonical(
                    "invalid_fee_payment: feePayment.chargeLimits must be unique and ordered nexus before pipelineGas"
                )
            }
            previous = Int64(limit.kindTag)
            try checkQuantity(limit.maxAmount, label: "feePayment.chargeLimits[\(index)].maxAmount")
        }
        if let gasLimit = fee.gasLimit, gasLimit == 0 {
            throw Failure.notCanonical("invalid_integer: feePayment.gasLimit must be non-zero when provided")
        }
        guard fee.sponsor != nil else {
            return
        }
        guard let revision = fee.programRevision, revision != 0 else {
            throw Failure.notCanonical("invalid_fee_payment: feePayment.programRevision must be non-zero")
        }
        let name = fee.programName ?? ""
        try checkExactString(name, label: "feePayment.programId.name", maximumBytes: 255)
        guard !IrohaMetadataJSON.containsRustWhitespace(name), !name.contains(where: { "@#$".contains($0) }) else {
            throw Failure.notCanonical("invalid_fee_payment: feePayment.programId.name is not a canonical program Name")
        }
    }

    private static func checkContractCall(_ call: Reviewer.ContractCall, label: String) throws {
        try checkExactString(call.contractAddress, label: "\(label).contractAddress", maximumBytes: 256)
        guard IrohaContractAddress.isCanonical(call.contractAddress) else {
            throw Failure.notCanonical("invalid_input: \(label).contractAddress must be a canonical V1 Bech32m contract address")
        }
        guard call.expectedCodeHash.count == 32, call.expectedCodeHash[call.expectedCodeHash.count - 1] & 1 == 1 else {
            throw Failure.notCanonical("invalid_bytes: \(label).expectedCodeHash must carry the canonical Iroha hash marker bit")
        }
        try checkExactString(call.entrypoint, label: "\(label).entrypoint", maximumBytes: maximumContractEntrypointBytes)
        if let arguments = call.arguments, arguments.count > maximumContractArgumentBytes {
            throw Failure.notCanonical("bounds_exceeded: \(label).arguments exceeds \(maximumContractArgumentBytes) bytes")
        }
    }

    /// The SDK's `exactString`: non-empty, trimmed, bounded, free of C0/C1 controls, NFC.
    static func checkExactString(_ value: String, label: String, maximumBytes: Int) throws {
        guard !value.isEmpty, value.utf16.count <= maximumBytes, value.utf8.count <= maximumBytes else {
            throw Failure.notCanonical("invalid_input: \(label) must be a non-empty exact string")
        }
        guard let first = value.unicodeScalars.first, let last = value.unicodeScalars.last,
              !IrohaConnectWireCodec.isJavaScriptWhitespace(first),
              !IrohaConnectWireCodec.isJavaScriptWhitespace(last) else {
            throw Failure.notCanonical("invalid_input: \(label) must be a non-empty exact string")
        }
        guard !value.unicodeScalars.contains(where: { $0.value <= 0x1F || ($0.value >= 0x7F && $0.value <= 0x9F) }) else {
            throw Failure.notCanonical("invalid_input: \(label) must not contain control characters")
        }
        guard IrohaMetadataJSON.isNFC(value) else {
            throw Failure.notCanonical("invalid_input: \(label) must use NFC normalization")
        }
    }

    // MARK: - Archives

    private static func transferInstruction(
        owner: Reviewer.Account,
        definition: Data,
        scope: UInt64?,
        quantity: Reviewer.Quantity,
        destination: Reviewer.Account
    ) -> Data {
        let body = structure([
            structure([account(owner), elementBytes(definition), scopeArchive(scope)]),
            numeric(quantity),
            account(destination)
        ])
        let inner = u32(2) + field(body)
        let frame = IrohaConnectWireCodec.frameNorito(inner, schemaHash: transferSchemaHash, flags: compactLengthFlag)
        return field(stringValue("iroha.transfer")) + field(u64(UInt64(frame.count)) + frame)
    }

    private static func contractInvocation(_ call: Reviewer.ContractCall) -> Data {
        structure([
            stringValue(call.contractAddress),
            call.expectedCodeHash,
            stringValue(call.entrypoint),
            option(call.arguments.map { u64(UInt64($0.count)) + $0 })
        ])
    }

    private static func feeArchive(_ fee: Reviewer.Fee) -> Data {
        let chargeLimits = vector(fee.chargeLimits.map { limit in
            structure([u32(limit.kindTag), elementBytes(limit.definition), numeric(limit.maxAmount)])
        })
        let gasLimit = option(fee.gasLimit.map(u64))
        guard let sponsor = fee.sponsor else {
            return u32(0) + field(structure([chargeLimits, gasLimit]))
        }
        let programID = structure([account(sponsor), stringValue(fee.programName ?? "")])
        return u32(1) + field(structure([programID, u64(fee.programRevision ?? 0), chargeLimits, gasLimit]))
    }

    private static func account(_ account: Reviewer.Account) -> Data {
        let key = Data([0]) + account.publicKey
        return u32(0) + field(u64(UInt64(key.count)) + elementBytes(key))
    }

    private static func elementBytes(_ bytes: Data) -> Data {
        bytes.reduce(into: Data()) { $0 += field(Data([$1])) }
    }

    private static func scopeArchive(_ scope: UInt64?) -> Data {
        guard let scope else {
            return u32(0)
        }
        return u32(1) + field(field(u64(scope)))
    }

    private static func numeric(_ quantity: Reviewer.Quantity) -> Data {
        let mantissa = twosComplementBytes(quantity.mantissa)
        return structure([u32(UInt32(mantissa.count)) + mantissa, u32(quantity.scale)])
    }

    /// Minimal little-endian two's-complement bytes of a positive integer.
    static func twosComplementBytes(_ value: BigUInt) -> Data {
        guard value > 0 else {
            return Data()
        }
        var bytes = Data(value.serialize().reversed())
        if let last = bytes.last, last & 0x80 != 0 {
            bytes.append(0)
        }
        return bytes
    }

    // MARK: - Primitives (compact lengths)

    static func compactLength(_ value: UInt64) -> Data {
        var remaining = value
        var bytes = Data()
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 {
                byte |= 0x80
            }
            bytes.append(byte)
        } while remaining != 0
        return bytes
    }

    static func field(_ payload: Data) -> Data {
        compactLength(UInt64(payload.count)) + payload
    }

    static func structure(_ fields: [Data]) -> Data {
        fields.reduce(into: Data()) { $0 += field($1) }
    }

    static func vector(_ values: [Data]) -> Data {
        u64(UInt64(values.count)) + values.reduce(into: Data()) { $0 += field($1) }
    }

    static func option(_ value: Data?) -> Data {
        guard let value else {
            return Data([0])
        }
        return Data([1]) + field(value)
    }

    static func stringValue(_ value: String) -> Data {
        field(Data(value.utf8))
    }

    static func u32(_ value: UInt32) -> Data {
        IrohaConnectNorito.u32(value)
    }

    static func u64(_ value: UInt64) -> Data {
        IrohaConnectNorito.u64(value)
    }
}

/// Transaction metadata values must already be canonical JSON as the iroha-js codec writes it: compact, object
/// keys sorted by UTF-8 bytes, safe integers only, Rust-style string escapes.
enum IrohaMetadataJSON {
    typealias Failure = IrohaPayloadEncoder.Failure

    indirect enum Value: Equatable {
        case null
        case bool(Bool)
        case number(Int64)
        case string(String)
        case array([Value])
        case object([(String, Value)])

        static func == (lhs: Value, rhs: Value) -> Bool {
            canonical(lhs) == canonical(rhs)
        }
    }

    private static let maximumJSONBytes = 64 * 1024
    private static let maximumEntries = 64
    private static let maximumDepth = 32
    private static let maximumNodes = 4096
    private static let maximumKeyBytes = 255
    private static let maximumSafeInteger: Int64 = 9_007_199_254_740_991

    static func canonicalArchive(_ entries: [(key: String, json: String)], legacyKeys: Set<String>) throws -> Data {
        var nodes = 1
        var values = [(String, Value)]()
        for (key, text) in entries {
            try validateKey(key, context: "metadata key")
            var parser = Parser(text: text)
            let value = try parser.parseDocument()
            try normalize(value, context: "metadata.\(key)", depth: 1, nodes: &nodes)
            values.append((key, value))
        }
        guard values.count <= maximumEntries else {
            throw Failure.notCanonical("bounds_exceeded: metadata exceeds \(maximumEntries) top-level entries")
        }
        if let legacy = values.first(where: { legacyKeys.contains($0.0) }) {
            throw Failure.notCanonical("invalid_fee_payment: metadata.\(legacy.0) is retired; use the signature-bound feePayment field")
        }
        let sorted = values.sorted { utf8Less($0.0, $1.0) }
        guard canonical(.object(sorted)).utf8.count <= maximumJSONBytes else {
            throw Failure.notCanonical("bounds_exceeded: canonical metadata JSON exceeds 65536 UTF-8 bytes")
        }
        return IrohaPayloadEncoder.vector(sorted.map { key, value in
            IrohaPayloadEncoder.structure([
                IrohaPayloadEncoder.stringValue(key),
                IrohaPayloadEncoder.structure([IrohaPayloadEncoder.stringValue(canonical(value))])
            ])
        })
    }

    /// `JSON.stringify` of the decoded metadata, as the web review shows it: array-index keys first in numeric
    /// order, then the other keys in their (canonical) order.
    static func displayText(_ entries: [(key: String, json: String)]) -> String {
        var values = [(String, Value)]()
        for (key, text) in entries {
            var parser = Parser(text: text)
            guard let value = try? parser.parseDocument() else { continue }
            values.append((key, value))
        }
        return display(.object(values))
    }

    static func canonical(_ value: Value) -> String {
        switch value {
        case .null:
            return "null"
        case let .bool(flag):
            return flag ? "true" : "false"
        case let .number(number):
            return String(number)
        case let .string(text):
            return quoted(text)
        case let .array(items):
            return "[\(items.map(canonical).joined(separator: ","))]"
        case let .object(members):
            let sorted = members.sorted { utf8Less($0.0, $1.0) }
            return "{\(sorted.map { "\(quoted($0.0)):\(canonical($0.1))" }.joined(separator: ","))}"
        }
    }

    private static func display(_ value: Value) -> String {
        switch value {
        case let .array(items):
            return "[\(items.map(display).joined(separator: ","))]"
        case let .object(members):
            let indices = members.filter { arrayIndex($0.0) != nil }.sorted { arrayIndex($0.0)! < arrayIndex($1.0)! }
            let others = members.filter { arrayIndex($0.0) == nil }
            return "{\((indices + others).map { "\(quoted($0.0)):\(display($0.1))" }.joined(separator: ","))}"
        default:
            return canonical(value)
        }
    }

    private static func arrayIndex(_ key: String) -> UInt64? {
        guard let value = UInt64(key), String(value) == key, value < 4_294_967_295 else {
            return nil
        }
        return value
    }

    private static func quoted(_ text: String) -> String {
        var output = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"":
                output += "\\\""
            case "\\":
                output += "\\\\"
            case "\u{08}":
                output += "\\b"
            case "\u{0C}":
                output += "\\f"
            case "\n":
                output += "\\n"
            case "\r":
                output += "\\r"
            case "\t":
                output += "\\t"
            default:
                if scalar.value < 0x20 {
                    output += String(format: "\\u%04x", scalar.value)
                } else {
                    output.unicodeScalars.append(scalar)
                }
            }
        }
        return output + "\""
    }

    private static func normalize(_ value: Value, context: String, depth: Int, nodes: inout Int) throws {
        nodes += 1
        guard nodes <= maximumNodes else {
            throw Failure.notCanonical("bounds_exceeded: metadata exceeds \(maximumNodes) values")
        }
        guard depth <= maximumDepth else {
            throw Failure.notCanonical("bounds_exceeded: metadata nesting exceeds \(maximumDepth)")
        }
        switch value {
        case .null, .bool:
            return
        case let .number(number):
            guard number >= -maximumSafeInteger, number <= maximumSafeInteger else {
                throw Failure.notCanonical("invalid_metadata: \(context) numbers must be safe integers")
            }
        case let .string(text):
            guard text.utf16.count <= maximumJSONBytes, text.utf8.count <= maximumJSONBytes else {
                throw Failure.notCanonical("bounds_exceeded: \(context) string exceeds \(maximumJSONBytes) UTF-8 bytes")
            }
        case let .array(items):
            for (index, item) in items.enumerated() {
                try normalize(item, context: "\(context)[\(index)]", depth: depth + 1, nodes: &nodes)
            }
        case let .object(members):
            for (index, member) in members.enumerated() {
                try validateKey(member.0, context: "\(context) key \(index)")
            }
            for member in members.sorted(by: { utf8Less($0.0, $1.0) }) {
                try normalize(member.1, context: "\(context).\(member.0)", depth: depth + 1, nodes: &nodes)
            }
        }
    }

    /// A metadata `Name`: 1-255 code units and UTF-8 bytes, NFC, no Rust whitespace, no `@`, `#` or `$`.
    static func validateKey(_ key: String, context: String) throws {
        guard !key.isEmpty, key.utf16.count <= maximumKeyBytes, key.utf8.count <= maximumKeyBytes,
              isNFC(key), !containsRustWhitespace(key), !key.contains(where: { "@#$".contains($0) }) else {
            throw Failure.notCanonical("invalid_metadata: \(context) is not a canonical metadata Name")
        }
    }

    static func isNFC(_ value: String) -> Bool {
        Array(value.precomposedStringWithCanonicalMapping.unicodeScalars) == Array(value.unicodeScalars)
    }

    static func containsRustWhitespace(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x09 ... 0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2000 ... 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
                return true
            default:
                return false
            }
        }
    }

    static func utf8Less(_ lhs: String, _ rhs: String) -> Bool {
        Array(lhs.utf8).lexicographicallyPrecedes(Array(rhs.utf8))
    }

    /// Parses only canonical JSON: any other spelling of a value (whitespace, unsorted or repeated keys, other
    /// escapes or number forms) is not the codec's encoding and is refused.
    struct Parser {
        private let scalars: [Unicode.Scalar]
        private var index = 0

        init(text: String) {
            scalars = Array(text.unicodeScalars)
        }

        mutating func parseDocument() throws -> Value {
            let value = try parseValue()
            guard index == scalars.count else {
                throw notCanonical()
            }
            return value
        }

        private func notCanonical() -> Failure {
            Failure.notCanonical("invalid_metadata: metadata JSON strings must already use the exact canonical encoding")
        }

        private mutating func parseValue() throws -> Value {
            guard index < scalars.count else { throw notCanonical() }
            switch scalars[index] {
            case "n":
                try expect("null")
                return .null
            case "t":
                try expect("true")
                return .bool(true)
            case "f":
                try expect("false")
                return .bool(false)
            case "\"":
                return .string(try parseString())
            case "[":
                index += 1
                var items = [Value]()
                if index < scalars.count, scalars[index] == "]" {
                    index += 1
                    return .array(items)
                }
                while true {
                    items.append(try parseValue())
                    guard index < scalars.count else { throw notCanonical() }
                    if scalars[index] == "]" {
                        index += 1
                        return .array(items)
                    }
                    guard scalars[index] == "," else { throw notCanonical() }
                    index += 1
                }
            case "{":
                index += 1
                var members = [(String, Value)]()
                if index < scalars.count, scalars[index] == "}" {
                    index += 1
                    return .object(members)
                }
                while true {
                    guard index < scalars.count, scalars[index] == "\"" else { throw notCanonical() }
                    let key = try parseString()
                    if let previous = members.last?.0, !utf8Less(previous, key) {
                        throw notCanonical()
                    }
                    guard index < scalars.count, scalars[index] == ":" else { throw notCanonical() }
                    index += 1
                    members.append((key, try parseValue()))
                    guard index < scalars.count else { throw notCanonical() }
                    if scalars[index] == "}" {
                        index += 1
                        return .object(members)
                    }
                    guard scalars[index] == "," else { throw notCanonical() }
                    index += 1
                }
            default:
                return .number(try parseNumber())
            }
        }

        private mutating func expect(_ literal: String) throws {
            for scalar in literal.unicodeScalars {
                guard index < scalars.count, scalars[index] == scalar else { throw notCanonical() }
                index += 1
            }
        }

        private mutating func parseNumber() throws -> Int64 {
            let start = index
            if index < scalars.count, scalars[index] == "-" {
                index += 1
            }
            let digitsStart = index
            while index < scalars.count, ("0" ... "9").contains(scalars[index]) {
                index += 1
            }
            let digits = String(String.UnicodeScalarView(scalars[digitsStart ..< index]))
            let text = String(String.UnicodeScalarView(scalars[start ..< index]))
            guard !digits.isEmpty, digits == "0" || !digits.hasPrefix("0"), text != "-0",
                  digits.count <= 16, let value = Int64(text),
                  value >= -9_007_199_254_740_991, value <= 9_007_199_254_740_991 else {
                throw notCanonical()
            }
            return value
        }

        private mutating func parseString() throws -> String {
            index += 1
            var output = String.UnicodeScalarView()
            while index < scalars.count {
                let scalar = scalars[index]
                index += 1
                switch scalar {
                case "\"":
                    return String(output)
                case "\\":
                    guard index < scalars.count else { throw notCanonical() }
                    let escape = scalars[index]
                    index += 1
                    switch escape {
                    case "\"": output.append("\"")
                    case "\\": output.append("\\")
                    case "b": output.append("\u{08}")
                    case "f": output.append("\u{0C}")
                    case "n": output.append("\n")
                    case "r": output.append("\r")
                    case "t": output.append("\t")
                    case "u":
                        guard index + 4 <= scalars.count else { throw notCanonical() }
                        let hex = String(String.UnicodeScalarView(scalars[index ..< index + 4]))
                        index += 4
                        guard hex.hasPrefix("00"), hex == hex.lowercased(),
                              let value = UInt32(hex, radix: 16), value < 0x20,
                              ![0x08, 0x09, 0x0A, 0x0C, 0x0D].contains(value),
                              let decoded = Unicode.Scalar(value) else {
                            throw notCanonical()
                        }
                        output.append(decoded)
                    default:
                        throw notCanonical()
                    }
                default:
                    guard scalar.value >= 0x20 else { throw notCanonical() }
                    output.append(scalar)
                }
            }
            throw notCanonical()
        }
    }
}
