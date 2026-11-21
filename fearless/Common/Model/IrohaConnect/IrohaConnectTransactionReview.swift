import BigInt
import CryptoKit
import Foundation

// A Connect `SignRequestTx` carries an unsigned transaction payload. The wallet signs its hash only after
// decoding every signature-bound field into a review and proving the review is the payload: the decoded values
// are encoded again with the canonical rules of the iroha-js transaction codec and must reproduce the exact
// bytes. Anything else (instructions that need Iroha's native decoder, proof attachments, foreign authorities,
// other networks) is refused, never signed. Ported from fearless-wallet-web `transactionReview.ts`.

enum IrohaConnectTransactionError: Error, Equatable {
    case unsupported(String)
    case invalid(String)
    case wrongNetwork(String)
    case wrongAuthority(String)

    /// The web wallet's review error code.
    var code: String {
        switch self {
        case .unsupported:
            return "unsupported_transaction"
        case .invalid:
            return "invalid_transaction"
        case .wrongNetwork:
            return "wrong_network"
        case .wrongAuthority:
            return "wrong_authority"
        }
    }

    /// The code the dApp receives in `SignResultErr`.
    var resultCode: String {
        switch self {
        case .unsupported:
            return "UNSUPPORTED_TRANSACTION"
        case .invalid:
            return "INVALID_TRANSACTION"
        case .wrongNetwork:
            return "WRONG_NETWORK"
        case .wrongAuthority:
            return "WRONG_ACCOUNT"
        }
    }

    var detail: String {
        switch self {
        case let .unsupported(detail), let .invalid(detail), let .wrongNetwork(detail), let .wrongAuthority(detail):
            return detail
        }
    }
}

struct IrohaConnectReviewAsset: Equatable {
    let definitionID: String
    let symbol: String?
}

struct IrohaConnectReviewFeeLimit: Equatable {
    enum Kind: String, Equatable {
        case nexus
        case pipelineGas
    }

    let kind: Kind
    let asset: IrohaConnectReviewAsset
    let maxAmount: String
}

struct IrohaConnectReviewFee: Equatable {
    enum Payer: String, Equatable {
        case authority
        case sponsor
    }

    let payer: Payer
    let program: String?
    let programRevision: String?
    let chargeLimits: [IrohaConnectReviewFeeLimit]
    let gasLimit: String?
}

struct IrohaConnectReviewTransfer: Equatable {
    let asset: IrohaConnectReviewAsset
    let scope: String?
    let quantity: String
    let destination: String
}

struct IrohaConnectReviewContractCall: Equatable {
    let contractAddress: String
    let entrypoint: String
    let codeHashHex: String
    let argumentBytes: Int?
    let argumentsSHA256: String?
}

struct IrohaConnectTransactionReview: Equatable {
    enum Kind: String, Equatable {
        case transfer
        case contractCalls = "contract-calls"
    }

    let kind: Kind
    let authority: String
    let networkID: String
    let payloadBytes: Int
    let payloadHashHex: String
    let creationTimeMs: String
    let ttlMs: String?
    let nonce: String?
    let fee: IrohaConnectReviewFee
    /// Canonical metadata JSON with control and bidirectional characters escaped, or nil when empty.
    let metadata: String?
    let transfer: IrohaConnectReviewTransfer?
    let calls: [IrohaConnectReviewContractCall]?
}

struct IrohaConnectReviewedTransaction: Equatable {
    let review: IrohaConnectTransactionReview
    /// The marked Blake2b-256 payload hash the transaction key signs.
    let payloadHash: Data
}

struct IrohaConnectTransactionExpectation: Equatable {
    let networkID: IrohaConnectNetworkID
    let networkPrefix: Int
    let authority: String
    let signingPublicKey: Data
}

/// Escape control, format (including bidi) and line-separator characters, then bound the text (UTF-16 units,
/// as the web wallet counts them).
func irohaConnectSanitizedReviewText(_ value: String, maximum: Int = 512) -> String {
    var escaped = ""
    for scalar in value.unicodeScalars {
        switch scalar.properties.generalCategory {
        case .control, .format:
            escaped += "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
        default:
            if scalar.value == 0x2028 || scalar.value == 0x2029 {
                escaped += "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
            } else {
                escaped.unicodeScalars.append(scalar)
            }
        }
    }
    guard escaped.utf16.count > maximum else {
        return escaped
    }
    var truncated = ""
    var units = 0
    for scalar in escaped.unicodeScalars {
        let width = scalar.utf16.count
        guard units + width <= maximum - 1 else { break }
        truncated.unicodeScalars.append(scalar)
        units += width
    }
    return truncated + "…"
}

enum IrohaConnectTransactionReviewer {
    static let maximumPayloadBytes = 1024 * 1024
    private static let maximumMetadataText = 2048
    private static let maximumEntries = 64
    private static let maximumContractArgumentBytes = 1024 * 1024
    private static let transferWireID = "iroha.transfer"
    private static let assetDefinitionVersion: UInt8 = 1
    private static let knownAssets = [UniversalWalletRegistry.tairaNativeXorAssetDefinitionId: "XOR"]

    static func review(
        _ payload: Data,
        expectation: IrohaConnectTransactionExpectation
    ) throws -> IrohaConnectReviewedTransaction {
        guard !payload.isEmpty, payload.count <= maximumPayloadBytes else {
            throw IrohaConnectTransactionError.invalid("payload size is out of range")
        }
        let prefix = expectation.networkPrefix
        var reader = IrohaPayloadReader(payload, label: "payload")

        var domain = IrohaPayloadReader(try reader.readField("domain"), label: "payload.domain")
        guard try domain.readU32("variant") == 0 else {
            throw IrohaConnectTransactionError.unsupported("payload must target a network domain")
        }
        let payloadNetwork = try domain.readField("networkId")
        try domain.done()
        guard payloadNetwork == expectation.networkID.bytes else {
            throw IrohaConnectTransactionError.wrongNetwork("payload targets another network")
        }
        let authority = try readAccount(reader.readField("authority"), label: "payload.authority", prefix: prefix)
        guard authority.literal == expectation.authority else {
            throw IrohaConnectTransactionError.wrongAuthority("payload is not for the connected account")
        }
        let creationTimeMs = try readU64Field(reader.readField("creationTimeMs"), label: "payload.creationTimeMs")
        let executable = try readExecutable(reader.readField("executable"), prefix: prefix)
        let ttlMs = try readOptionUnsigned(reader.readField("ttlMs"), width: 8, label: "payload.ttlMs")
        let nonce = try readOptionUnsigned(reader.readField("nonce"), width: 4, label: "payload.nonce")
        let fee = try readFee(reader.readField("feePayment"), prefix: prefix)
        let metadata = try readMetadata(reader.readField("metadata"))
        let attachments = try reader.readField("attachments")
        try reader.done()
        guard attachments == Data([0]) else {
            throw IrohaConnectTransactionError.unsupported("proof attachments are not reviewable")
        }

        let rebuilt: Data
        do {
            rebuilt = try IrohaPayloadEncoder.payload(
                networkID: payloadNetwork,
                authority: authority,
                creationTimeMs: creationTimeMs,
                executable: executable,
                ttlMs: ttlMs,
                nonce: nonce,
                fee: fee,
                metadata: metadata
            )
        } catch let IrohaPayloadEncoder.Failure.notCanonical(detail) {
            throw IrohaConnectTransactionError.invalid(
                "payload is not canonical: \(irohaConnectSanitizedReviewText(detail, maximum: 240))"
            )
        }
        guard rebuilt == payload else {
            throw IrohaConnectTransactionError.invalid("payload is not the canonical encoding of its fields")
        }
        guard authority.publicKey == expectation.signingPublicKey else {
            throw IrohaConnectTransactionError.invalid("payload does not validate: the signing key does not control authority")
        }

        let payloadHash = irohaHash(payload)
        let review = IrohaConnectTransactionReview(
            kind: executable.kind,
            authority: authority.literal,
            networkID: expectation.networkID.literal,
            payloadBytes: payload.count,
            payloadHashHex: payloadHash.irohaConnectHex,
            creationTimeMs: String(creationTimeMs),
            ttlMs: ttlMs.map { String($0) },
            nonce: nonce.map { String($0) },
            fee: fee.review,
            metadata: metadata.isEmpty
                ? nil
                : irohaConnectSanitizedReviewText(IrohaMetadataJSON.displayText(metadata), maximum: maximumMetadataText),
            transfer: executable.transferReview,
            calls: executable.callReviews
        )
        return IrohaConnectReviewedTransaction(review: review, payloadHash: payloadHash)
    }

    /// Iroha's `HashOf<TransactionPayload>`: Blake2b-256 with the last bit set.
    static func irohaHash(_ payload: Data) -> Data {
        var digest = (try? IrohaConnectWireCodec.blake2b256(payload)) ?? Data(count: 32)
        digest[digest.count - 1] |= 1
        return digest
    }

    // MARK: - Decoding

    struct Account: Equatable {
        let literal: String
        let publicKey: Data
    }

    struct Quantity: Equatable {
        let mantissa: BigUInt
        let mantissaBytes: Data
        let scale: UInt32
        let text: String
    }

    struct FeeLimit: Equatable {
        let kindTag: UInt32
        let definition: Data
        let asset: IrohaConnectReviewAsset
        let maxAmount: Quantity
    }

    struct Fee: Equatable {
        let sponsor: Account?
        let programName: String?
        let programRevision: UInt64?
        let chargeLimits: [FeeLimit]
        let gasLimit: UInt64?

        var review: IrohaConnectReviewFee {
            IrohaConnectReviewFee(
                payer: sponsor == nil ? .authority : .sponsor,
                program: sponsor.map { irohaConnectSanitizedReviewText("\($0.literal)/\(programName ?? "")") },
                programRevision: programRevision.map { String($0) },
                chargeLimits: chargeLimits.map {
                    IrohaConnectReviewFeeLimit(
                        kind: $0.kindTag == 0 ? .nexus : .pipelineGas,
                        asset: $0.asset,
                        maxAmount: $0.maxAmount.text
                    )
                },
                gasLimit: gasLimit.map { String($0) }
            )
        }
    }

    struct ContractCall: Equatable {
        let contractAddress: String
        let expectedCodeHash: Data
        let entrypoint: String
        let arguments: Data?
    }

    enum Executable: Equatable {
        case transfer(
            sourceOwner: Account,
            definition: Data,
            asset: IrohaConnectReviewAsset,
            scope: UInt64?,
            quantity: Quantity,
            destination: Account
        )
        case contractCalls([ContractCall])

        var kind: IrohaConnectTransactionReview.Kind {
            if case .transfer = self { return .transfer }
            return .contractCalls
        }

        var transferReview: IrohaConnectReviewTransfer? {
            guard case let .transfer(_, _, asset, scope, quantity, destination) = self else { return nil }
            return IrohaConnectReviewTransfer(
                asset: asset,
                scope: scope.map { "dataspace:\($0)" },
                quantity: quantity.text,
                destination: destination.literal
            )
        }

        var callReviews: [IrohaConnectReviewContractCall]? {
            guard case let .contractCalls(calls) = self else { return nil }
            return calls.map { call in
                IrohaConnectReviewContractCall(
                    contractAddress: irohaConnectSanitizedReviewText(call.contractAddress),
                    entrypoint: irohaConnectSanitizedReviewText(call.entrypoint),
                    codeHashHex: call.expectedCodeHash.irohaConnectHex,
                    argumentBytes: call.arguments?.count,
                    argumentsSHA256: call.arguments.map { Data(SHA256.hash(data: $0)).irohaConnectHex }
                )
            }
        }
    }

    private static func readText(_ archive: Data, label: String) throws -> String {
        var reader = IrohaPayloadReader(archive, label: label)
        let value = try reader.readField("utf8")
        try reader.done()
        guard let text = String(data: value, encoding: .utf8) else {
            throw IrohaConnectTransactionError.invalid("\(label) is not UTF-8")
        }
        return text
    }

    private static func readU64Field(_ bytes: Data, label: String) throws -> UInt64 {
        guard bytes.count == 8 else {
            throw IrohaConnectTransactionError.invalid("\(label) must be a u64")
        }
        var reader = IrohaPayloadReader(bytes, label: label)
        return try reader.readU64("value")
    }

    private static func readOptionUnsigned(_ bytes: Data, width: Int, label: String) throws -> UInt64? {
        var reader = IrohaPayloadReader(bytes, label: label)
        let tag = try reader.readU8("tag")
        if tag == 0 {
            try reader.done()
            return nil
        }
        guard tag == 1 else {
            throw IrohaConnectTransactionError.invalid("\(label) has an invalid option tag")
        }
        let value = try reader.readField("value")
        try reader.done()
        guard value.count == width else {
            throw IrohaConnectTransactionError.invalid("\(label) has the wrong width")
        }
        var valueReader = IrohaPayloadReader(value, label: label)
        return width == 8 ? try valueReader.readU64("value") : UInt64(try valueReader.readU32("value"))
    }

    private static func readElementBytes(_ bytes: Data, count: Int, label: String) throws -> Data {
        var reader = IrohaPayloadReader(bytes, label: label)
        var output = Data()
        for index in 0 ..< count {
            let element = try reader.readField("[\(index)]")
            guard element.count == 1 else {
                throw IrohaConnectTransactionError.invalid("\(label)[\(index)] must be one byte")
            }
            output += element
        }
        try reader.done()
        return output
    }

    private static func readAccount(_ archive: Data, label: String, prefix: Int) throws -> Account {
        var reader = IrohaPayloadReader(archive, label: label)
        guard try reader.readU32("controller") == 0 else {
            throw IrohaConnectTransactionError.unsupported("\(label) is not a single-key account")
        }
        var controller = IrohaPayloadReader(try reader.readField("key"), label: "\(label).key")
        try reader.done()
        guard try controller.readU64("count") == 33 else {
            throw IrohaConnectTransactionError.invalid("\(label) key must be 33 bytes")
        }
        let key = try readElementBytes(controller.readBytes(controller.remaining, "bytes"), count: 33, label: "\(label).key")
        guard key[key.startIndex] == 0 else {
            throw IrohaConnectTransactionError.unsupported("\(label) is not an Ed25519 account")
        }
        let publicKey = Data(key.dropFirst())
        guard IrohaEd25519PublicKey.isValid(publicKey),
              let literal = try? IrohaAddressCodec.encode(
                  publicKeyHex: publicKey.irohaConnectHex,
                  chainDiscriminant: prefix
              ) else {
            throw IrohaConnectTransactionError.invalid("\(label) has an invalid public key")
        }
        return Account(literal: literal, publicKey: publicKey)
    }

    private static func readAssetDefinition(_ archive: Data, label: String) throws -> (Data, IrohaConnectReviewAsset) {
        let definition = try readElementBytes(archive, count: 16, label: label)
        let versioned = Data([assetDefinitionVersion]) + definition
        guard let checksum = IrohaBlake3.hash(versioned) else {
            throw IrohaConnectTransactionError.invalid("\(label) checksum is unavailable")
        }
        let definitionID = IrohaBase58.encode(versioned + checksum.prefix(4))
        return (definition, IrohaConnectReviewAsset(definitionID: definitionID, symbol: knownAssets[definitionID]))
    }

    private static func readScope(_ archive: Data, label: String) throws -> UInt64? {
        var reader = IrohaPayloadReader(archive, label: label)
        let tag = try reader.readU32("tag")
        if tag == 0 {
            try reader.done()
            return nil
        }
        guard tag == 1 else {
            throw IrohaConnectTransactionError.invalid("\(label) has an unsupported tag")
        }
        var outer = IrohaPayloadReader(try reader.readField("dataspace"), label: "\(label).dataspace")
        try reader.done()
        let value = try readU64Field(outer.readField("value"), label: "\(label).dataspace")
        try outer.done()
        return value
    }

    private static func readQuantity(_ archive: Data, label: String) throws -> Quantity {
        var reader = IrohaPayloadReader(archive, label: label)
        var mantissaArchive = IrohaPayloadReader(try reader.readField("mantissa"), label: "\(label).mantissa")
        let scaleBytes = try reader.readField("scale")
        try reader.done()
        let mantissaBytes = try mantissaArchive.readBytes(Int(try mantissaArchive.readU32("length")), "bytes")
        try mantissaArchive.done()
        guard scaleBytes.count == 4 else {
            throw IrohaConnectTransactionError.invalid("\(label).scale must be a u32")
        }
        var scaleReader = IrohaPayloadReader(scaleBytes, label: "\(label).scale")
        let scale = try scaleReader.readU32("scale")
        guard scale <= 28, !mantissaBytes.isEmpty, mantissaBytes.count <= 64 else {
            throw IrohaConnectTransactionError.invalid("\(label) is out of range")
        }
        guard mantissaBytes[mantissaBytes.count - 1] & 0x80 == 0 else {
            throw IrohaConnectTransactionError.invalid("\(label) must be positive")
        }
        let mantissa = BigUInt(Data(mantissaBytes.reversed()))
        let digits = String(mantissa)
        let padded = String(repeating: "0", count: max(0, Int(scale) + 1 - digits.count)) + digits
        let text = scale == 0
            ? padded
            : "\(padded.dropLast(Int(scale))).\(padded.suffix(Int(scale)))"
        return Quantity(mantissa: mantissa, mantissaBytes: mantissaBytes, scale: scale, text: text)
    }

    private static func readFee(_ archive: Data, prefix: Int) throws -> Fee {
        var reader = IrohaPayloadReader(archive, label: "feePayment")
        let payer = try reader.readU32("payer")
        var body = IrohaPayloadReader(try reader.readField("value"), label: "feePayment.value")
        try reader.done()
        guard payer <= 1 else {
            throw IrohaConnectTransactionError.unsupported("feePayment uses an unknown payer")
        }
        var sponsor: Account?
        var programName: String?
        var programRevision: UInt64?
        if payer == 1 {
            var programID = IrohaPayloadReader(try body.readField("programId"), label: "feePayment.programId")
            sponsor = try readAccount(programID.readField("sponsor"), label: "feePayment.sponsor", prefix: prefix)
            programName = try readText(programID.readField("name"), label: "feePayment.programId.name")
            try programID.done()
            programRevision = try readU64Field(body.readField("programRevision"), label: "feePayment.programRevision")
        }
        var limits = IrohaPayloadReader(try body.readField("chargeLimits"), label: "feePayment.chargeLimits")
        let count = try limits.readU64("count")
        guard count <= 2 else {
            throw IrohaConnectTransactionError.invalid("feePayment has too many charge limits")
        }
        var chargeLimits = [FeeLimit]()
        for index in 0 ..< Int(count) {
            var entry = IrohaPayloadReader(try limits.readField("[\(index)]"), label: "feePayment.chargeLimits[\(index)]")
            let kindBytes = try entry.readField("kind")
            guard kindBytes.count == 4 else {
                throw IrohaConnectTransactionError.invalid("feePayment charge kind must be a u32")
            }
            var kindReader = IrohaPayloadReader(kindBytes, label: "feePayment.kind")
            let kindTag = try kindReader.readU32("kind")
            guard kindTag <= 1 else {
                throw IrohaConnectTransactionError.unsupported("feePayment uses an unknown charge kind")
            }
            let (definition, asset) = try readAssetDefinition(
                entry.readField("assetDefinitionId"),
                label: "feePayment.assetDefinitionId"
            )
            let maxAmount = try readQuantity(entry.readField("maxAmount"), label: "feePayment.maxAmount")
            try entry.done()
            chargeLimits.append(FeeLimit(kindTag: kindTag, definition: definition, asset: asset, maxAmount: maxAmount))
        }
        try limits.done()
        let gasLimit = try readOptionUnsigned(body.readField("gasLimit"), width: 8, label: "feePayment.gasLimit")
        try body.done()
        return Fee(
            sponsor: sponsor,
            programName: programName,
            programRevision: programRevision,
            chargeLimits: chargeLimits,
            gasLimit: gasLimit
        )
    }

    private static func readMetadata(_ archive: Data) throws -> [(key: String, json: String)] {
        var reader = IrohaPayloadReader(archive, label: "metadata")
        let count = try reader.readU64("count")
        guard count <= UInt64(maximumEntries) else {
            throw IrohaConnectTransactionError.invalid("metadata has too many entries")
        }
        var entries = [(key: String, json: String)]()
        for index in 0 ..< Int(count) {
            var entry = IrohaPayloadReader(try reader.readField("[\(index)]"), label: "metadata[\(index)]")
            let key = try readText(entry.readField("key"), label: "metadata[\(index)].key")
            var json = IrohaPayloadReader(try entry.readField("json"), label: "metadata[\(index)].json")
            let text = try readText(json.readField("value"), label: "metadata[\(index)].json")
            try json.done()
            try entry.done()
            guard !entries.contains(where: { Array($0.key.utf8) == Array(key.utf8) }) else {
                throw IrohaConnectTransactionError.invalid("metadata keys must be unique")
            }
            entries.append((key, text))
        }
        try reader.done()
        return entries
    }

    private static func readTransferInstruction(_ archive: Data, prefix: Int) throws -> Executable {
        var instruction = IrohaPayloadReader(archive, label: "instruction")
        let wireID = try readText(instruction.readField("wireId"), label: "instruction.wireId")
        guard Array(wireID.utf8) == Array(transferWireID.utf8) else {
            throw IrohaConnectTransactionError.unsupported(
                "instruction \(irohaConnectSanitizedReviewText(wireID, maximum: 96)) needs the native decoder"
            )
        }
        var container = IrohaPayloadReader(try instruction.readField("frameContainer"), label: "instruction.frameContainer")
        try instruction.done()
        let frame = try container.readFieldU64("frame")
        try container.done()
        // NRT0 header: magic(4) version(2) schema(16) reserved(1) length(8) crc64(8) flags(1). The rebuild checks the
        // schema hash, checksum and flags byte for byte.
        guard frame.count >= 40 else {
            throw IrohaConnectTransactionError.invalid("transfer frame is truncated")
        }
        var transfer = IrohaPayloadReader(Data(frame.dropFirst(40)), label: "transfer")
        guard try transfer.readU32("variant") == 2 else {
            throw IrohaConnectTransactionError.unsupported("only Transfer::Asset is reviewable")
        }
        var body = IrohaPayloadReader(try transfer.readField("body"), label: "transfer.body")
        try transfer.done()
        var source = IrohaPayloadReader(try body.readField("source"), label: "transfer.source")
        let sourceOwner = try readAccount(source.readField("owner"), label: "transfer.source.owner", prefix: prefix)
        let (definition, asset) = try readAssetDefinition(source.readField("definition"), label: "transfer.source.definition")
        let scope = try readScope(source.readField("scope"), label: "transfer.source.scope")
        try source.done()
        let quantity = try readQuantity(body.readField("quantity"), label: "transfer.quantity")
        let destination = try readAccount(body.readField("destination"), label: "transfer.destination", prefix: prefix)
        try body.done()
        return .transfer(
            sourceOwner: sourceOwner,
            definition: definition,
            asset: asset,
            scope: scope,
            quantity: quantity,
            destination: destination
        )
    }

    private static func readContractCall(_ archive: Data) throws -> ContractCall {
        var invocation = IrohaPayloadReader(archive, label: "contractCall")
        let contractAddress = try readText(invocation.readField("contractAddress"), label: "contractCall.contractAddress")
        let expectedCodeHash = try invocation.readField("expectedCodeHash")
        guard expectedCodeHash.count == 32 else {
            throw IrohaConnectTransactionError.invalid("contractCall.expectedCodeHash must be 32 bytes")
        }
        let entrypoint = try readText(invocation.readField("entrypoint"), label: "contractCall.entrypoint")
        var option = IrohaPayloadReader(try invocation.readField("arguments"), label: "contractCall.arguments")
        try invocation.done()
        let tag = try option.readU8("tag")
        var arguments: Data?
        if tag == 1 {
            var record = IrohaPayloadReader(try option.readField("value"), label: "contractCall.arguments.value")
            let length = try record.readU64("length")
            guard length <= UInt64(record.remaining) else {
                throw IrohaConnectTransactionError.invalid("contractCall.arguments.value.bytes is truncated")
            }
            arguments = try record.readBytes(Int(length), "bytes")
            try record.done()
        } else if tag != 0 {
            throw IrohaConnectTransactionError.invalid("contractCall.arguments has an invalid option tag")
        }
        try option.done()
        return ContractCall(
            contractAddress: contractAddress,
            expectedCodeHash: expectedCodeHash,
            entrypoint: entrypoint,
            arguments: arguments
        )
    }

    private static func readExecutable(_ archive: Data, prefix: Int) throws -> Executable {
        var executable = IrohaPayloadReader(archive, label: "executable")
        let variant = try executable.readU32("variant")
        var list = IrohaPayloadReader(try executable.readField("items"), label: "executable.items")
        try executable.done()
        let count = try list.readU64("count")
        guard count > 0, count <= UInt64(maximumEntries) else {
            throw IrohaConnectTransactionError.invalid("executable has no or too many entries")
        }

        if variant == 0 {
            guard count == 1 else {
                throw IrohaConnectTransactionError.unsupported(
                    "instruction lists other than one asset transfer need the native decoder"
                )
            }
            let decoded = try readTransferInstruction(list.readField("[0]"), prefix: prefix)
            try list.done()
            return decoded
        }
        guard variant == 4 else {
            throw IrohaConnectTransactionError.unsupported("executable variant \(variant) is not reviewable")
        }

        var calls = [ContractCall]()
        for index in 0 ..< Int(count) {
            var entry = IrohaPayloadReader(try list.readField("[\(index)]"), label: "executable.entries[\(index)]")
            let tag = try entry.readU32("variant")
            let value = try entry.readField("value")
            try entry.done()
            guard tag == 1 else {
                throw IrohaConnectTransactionError.unsupported("batches with native instructions need the native decoder")
            }
            calls.append(try readContractCall(value))
        }
        try list.done()
        return .contractCalls(calls)
    }
}

/// Bounds-checked reader for transaction payloads: fields carry canonical LEB128 ("compact") lengths.
struct IrohaPayloadReader {
    private let bytes: [UInt8]
    private let label: String
    private var offset = 0

    init(_ data: Data, label: String) {
        bytes = [UInt8](data)
        self.label = label
    }

    var remaining: Int {
        bytes.count - offset
    }

    mutating func readBytes(_ count: Int, _ name: String) throws -> Data {
        guard count >= 0, count <= remaining else {
            throw IrohaConnectTransactionError.invalid("\(label).\(name) is truncated")
        }
        defer { offset += count }
        return Data(bytes[offset ..< offset + count])
    }

    mutating func readU8(_ name: String) throws -> UInt8 {
        try readBytes(1, name)[0]
    }

    mutating func readU32(_ name: String) throws -> UInt32 {
        try readBytes(4, name).withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }

    mutating func readU64(_ name: String) throws -> UInt64 {
        try readBytes(8, name).withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(as: UInt64.self)) }
    }

    mutating func readField(_ name: String) throws -> Data {
        let start = offset
        var length: UInt64 = 0
        var shift: UInt64 = 0
        for _ in 0 ..< 10 {
            let byte = try readU8("\(name).length")
            length |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                guard offset - start == IrohaPayloadEncoder.compactLength(length).count else {
                    throw IrohaConnectTransactionError.invalid("\(label).\(name) length is not canonical")
                }
                guard length <= UInt64(remaining) else {
                    throw IrohaConnectTransactionError.invalid("\(label).\(name) is truncated")
                }
                return try readBytes(Int(length), name)
            }
            shift += 7
        }
        throw IrohaConnectTransactionError.invalid("\(label).\(name) length prefix is invalid")
    }

    /// The transfer instruction's frame container keeps a fixed u64 length prefix.
    mutating func readFieldU64(_ name: String) throws -> Data {
        let length = try readU64("\(name).length")
        guard length <= UInt64(remaining) else {
            throw IrohaConnectTransactionError.invalid("\(label).\(name) is truncated")
        }
        return try readBytes(Int(length), name)
    }

    func done() throws {
        guard remaining == 0 else {
            throw IrohaConnectTransactionError.invalid("\(label) has trailing bytes")
        }
    }
}
