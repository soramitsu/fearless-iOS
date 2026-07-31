import BigInt
import CryptoKit
import Foundation
import TonSwift

enum TonTransferTransactionBuilderError: Error, Equatable {
    case unsupportedAsset
    case unsupportedNetwork
    case invalidPrivateKey
    case invalidPublicKey
    case invalidSenderAddress
    case invalidRecipientAddress
    case testnetAddressNotAllowed
    case unsupportedWorkchain
    case senderKeyMismatch
    case senderEqualsRecipient
    case ambiguousBounceFlag
    case bounceFlagMismatch
    case invalidAmount
    case invalidSequenceNumber
    case invalidStateInitPolicy
    case invalidExpiration
    case invalidComment
    case invalidSignature
    case serializationFailed
}

enum TonTransferAsset: Equatable, Hashable, Sendable {
    case nativeTon
    case jetton(masterAddress: String)
}

enum TonTransferNetwork: Equatable, Hashable, Sendable {
    case mainnet
    case testnet
}

struct TonTransferTransactionRequest: Equatable, Sendable {
    let asset: TonTransferAsset
    let network: TonTransferNetwork
    let senderAddress: String
    let recipientAddress: String
    let amountNanotons: String
    let sequenceNumber: UInt64
    let includeStateInit: Bool?
    let validUntil: UInt64
    let bounce: Bool
    let comment: String?

    init(
        asset: TonTransferAsset = .nativeTon,
        network: TonTransferNetwork = .mainnet,
        senderAddress: String,
        recipientAddress: String,
        amountNanotons: String,
        sequenceNumber: UInt64,
        includeStateInit: Bool? = nil,
        validUntil: UInt64,
        bounce: Bool,
        comment: String?
    ) {
        self.asset = asset
        self.network = network
        self.senderAddress = senderAddress
        self.recipientAddress = recipientAddress
        self.amountNanotons = amountNanotons
        self.sequenceNumber = sequenceNumber
        self.includeStateInit = includeStateInit
        self.validUntil = validUntil
        self.bounce = bounce
        self.comment = comment
    }
}

struct TonSignedExternalMessage: Equatable, Sendable {
    let boc: Data
    let bocBase64: String
    let messageHashHex: String
    let signingPayloadHashHex: String
    let publicKey: Data
    let walletAddress: String
    let sequenceNumber: UInt64
    let validUntil: UInt64
    let includesStateInit: Bool
}

/// An external message bearing TonSwift's deliberately invalid empty-key signature. Keeping
/// this separate from `TonSignedExternalMessage` makes it impossible to pass fee previews to
/// the broadcast API by accident.
struct TonUnsignedEmulationMessage: Equatable, Sendable {
    let boc: Data
    let bocBase64: String
    let messageHashHex: String
    let signingPayloadHashHex: String
    let publicKey: Data
    let walletAddress: String
    let sequenceNumber: UInt64
    let validUntil: UInt64
    let includesStateInit: Bool
}

private struct TonExternalMessageEnvelope {
    let boc: Data
    let bocBase64: String
    let messageHashHex: String
    let signingPayloadHashHex: String
    let publicKey: Data
    let walletAddress: String
    let sequenceNumber: UInt64
    let validUntil: UInt64
    let includesStateInit: Bool
}

struct TonSignedMessageInspection: Equatable, Sendable {
    let messageHashHex: String
    let signingPayloadHashHex: String
    let signature: Data
    let walletID: UInt64
    let walletAddress: String
    let recipientAddress: String
    let amountNanotons: String
    let sequenceNumber: UInt64
    let validUntil: UInt64
    let includesStateInit: Bool
    let bounce: Bool
    let messageBodyHashHex: String
}

/// Builds a signed TON Wallet V4R2 external message without performing network I/O.
///
/// Callers must obtain the sequence number and recipient account state from a reviewed
/// mainnet source. Production routing remains disabled until funded live evidence exists.
enum TonTransferTransactionBuilder {
    static let minimumLifetimeSeconds: UInt64 = 30
    static let maximumLifetimeSeconds: UInt64 = 300
    static let maximumCommentBytes = 256
    static let maximumAddressInputBytes = 128
    static let maximumAmountDigits = 37

    private static let privateKeyLength = 32
    private static let publicKeyLength = 32
    static let maximumBocBytes = 16 * 1024
    private static let maximumCoins = (BigUInt(1) << 120) - 1
    private static let supportedRecipientWorkchains: Set<Int8> = [0, -1]

    static func buildAndSign(
        request: TonTransferTransactionRequest,
        privateKeySeed: Data,
        now: UInt64
    ) throws -> TonSignedExternalMessage {
        do {
            try validateSupportedScope(asset: request.asset, network: request.network)
            let privateKey = try validatedPrivateKey(seed: privateKeySeed)
            let publicKey = privateKey.publicKey.rawRepresentation
            guard publicKey.count == publicKeyLength else {
                throw TonTransferTransactionBuilderError.invalidPrivateKey
            }

            let secretKey = privateKeySeed + publicKey
            guard secretKey.count == privateKeyLength + publicKeyLength else {
                throw TonTransferTransactionBuilderError.invalidPrivateKey
            }
            let message = try build(
                request: request,
                publicKey: publicKey,
                signer: WalletTransferSecretKeySigner(secretKey: secretKey),
                now: now
            )
            return TonSignedExternalMessage(
                boc: message.boc,
                bocBase64: message.bocBase64,
                messageHashHex: message.messageHashHex,
                signingPayloadHashHex: message.signingPayloadHashHex,
                publicKey: message.publicKey,
                walletAddress: message.walletAddress,
                sequenceNumber: message.sequenceNumber,
                validUntil: message.validUntil,
                includesStateInit: message.includesStateInit
            )
        } catch let error as TonTransferTransactionBuilderError {
            throw error
        } catch {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
    }

    /// Builds the same transfer envelope with a deliberately invalid 64-byte signature.
    /// This payload is only valid with TonAPI's explicit `ignore_signature_check` emulation
    /// option and cannot authorize a blockchain transaction.
    static func buildForFeeEstimation(
        request: TonTransferTransactionRequest,
        publicKey: Data,
        now: UInt64
    ) throws -> TonUnsignedEmulationMessage {
        do {
            try validateSupportedScope(asset: request.asset, network: request.network)
            try validatePublicKey(publicKey)
            let message = try build(
                request: request,
                publicKey: publicKey,
                signer: WalletTransferEmptyKeySigner(),
                now: now
            )
            return TonUnsignedEmulationMessage(
                boc: message.boc,
                bocBase64: message.bocBase64,
                messageHashHex: message.messageHashHex,
                signingPayloadHashHex: message.signingPayloadHashHex,
                publicKey: message.publicKey,
                walletAddress: message.walletAddress,
                sequenceNumber: message.sequenceNumber,
                validUntil: message.validUntil,
                includesStateInit: message.includesStateInit
            )
        } catch let error as TonTransferTransactionBuilderError {
            throw error
        } catch {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
    }

    /// Rebuilds the canonical Wallet V4R2 envelope around an already-created signature.
    /// This is used only to validate a persisted bearer BOC byte-for-byte after restart.
    static func rebuildSignedMessage(
        request: TonTransferTransactionRequest,
        publicKey: Data,
        signature: Data,
        now: UInt64
    ) throws -> TonSignedExternalMessage {
        guard signature.count == 64 else {
            throw TonTransferTransactionBuilderError.invalidSignature
        }
        do {
            try validateSupportedScope(asset: request.asset, network: request.network)
            try validatePublicKey(publicKey)
            let message = try build(
                request: request,
                publicKey: publicKey,
                signer: TonFixedSignatureSigner(signature: signature),
                now: now
            )
            return TonSignedExternalMessage(
                boc: message.boc,
                bocBase64: message.bocBase64,
                messageHashHex: message.messageHashHex,
                signingPayloadHashHex: message.signingPayloadHashHex,
                publicKey: message.publicKey,
                walletAddress: message.walletAddress,
                sequenceNumber: message.sequenceNumber,
                validUntil: message.validUntil,
                includesStateInit: message.includesStateInit
            )
        } catch let error as TonTransferTransactionBuilderError {
            throw error
        } catch {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
    }

    /// Strictly inspects the exact single-root signed BOC. Callers independently compare
    /// this result with the journal record and a byte-for-byte canonical rebuild.
    static func inspectSignedMessage(_ boc: Data) throws -> TonSignedMessageInspection {
        guard !boc.isEmpty, boc.count <= maximumBocBytes else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        let roots = try Cell.fromBoc(src: boc)
        guard roots.count == 1 else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        let root = roots[0]
        let rootSlice = try root.beginParse()
        let externalMessage = try Message.loadFrom(slice: rootSlice)

        guard case let .externalInInfo(externalInfo) = externalMessage.info,
              externalInfo.src == nil,
              externalInfo.importFee.rawValue == 0
        else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }

        let bodySlice = try externalMessage.body.beginParse()
        guard bodySlice.remainingBits >= 512 else {
            throw TonTransferTransactionBuilderError.invalidSignature
        }
        let signature = try bodySlice.loadBytes(64)
        let signingCell = try bodySlice.clone().toCell()
        let walletID = try bodySlice.loadUint(bits: 32)
        let validUntil = try bodySlice.loadUint(bits: 32)
        let sequenceNumber = try bodySlice.loadUint(bits: 32)
        let operation = try bodySlice.loadUint(bits: 8)
        let sendMode = try bodySlice.loadUint(bits: 8)
        guard operation == 0,
              sendMode == UInt64(SendMode.walletDefault().rawValue),
              bodySlice.remainingRefs == 1
        else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        let internalCell = try bodySlice.loadRef()
        try bodySlice.endParse()

        let internalSlice = try internalCell.beginParse()
        let internalMessage = try MessageRelaxed.loadFrom(slice: internalSlice)
        guard case let .internalInfo(internalInfo) = internalMessage.info,
              internalInfo.ihrDisabled,
              !internalInfo.bounced,
              try internalInfo.src.asInternal() == nil,
              internalInfo.value.other.isEmpty,
              internalInfo.ihrFee.rawValue == 0,
              internalInfo.forwardFee.rawValue == 0,
              internalInfo.createdLt == 0,
              internalInfo.createdAt == 0,
              internalMessage.stateInit == nil
        else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }

        return TonSignedMessageInspection(
            messageHashHex: root.hash().tonHexString,
            signingPayloadHashHex: signingCell.hash().tonHexString,
            signature: signature,
            walletID: walletID,
            walletAddress: externalInfo.dest.toRaw(),
            recipientAddress: internalInfo.dest.toRaw(),
            amountNanotons: internalInfo.value.coins.rawValue.description,
            sequenceNumber: sequenceNumber,
            validUntil: validUntil,
            includesStateInit: externalMessage.stateInit != nil,
            bounce: internalInfo.bounce,
            messageBodyHashHex: internalMessage.body.hash().tonHexString
        )
    }

    static func messageBodyHashHex(comment: String?) throws -> String {
        try validateComment(comment)
        return try messageBody(comment: comment).hash().tonHexString
    }

    private static func build(
        request: TonTransferTransactionRequest,
        publicKey: Data,
        signer: WalletTransferSigner,
        now: UInt64
    ) throws -> TonExternalMessageEnvelope {
        let sender = try parseAddress(request.senderAddress, role: .sender)
        let recipient = try parseAddress(request.recipientAddress, role: .recipient)
        try validateMainnetAddress(sender, role: .sender)
        try validateMainnetAddress(recipient, role: .recipient)

        guard sender.address.workchain == 0 else {
            throw TonTransferTransactionBuilderError.unsupportedWorkchain
        }
        guard supportedRecipientWorkchains.contains(recipient.address.workchain) else {
            throw TonTransferTransactionBuilderError.unsupportedWorkchain
        }

        let wallet = WalletV4R2(workchain: 0, publicKey: publicKey)
        let walletAddress = try wallet.address()
        guard sender.address == walletAddress else {
            throw TonTransferTransactionBuilderError.senderKeyMismatch
        }
        guard recipient.address != walletAddress else {
            throw TonTransferTransactionBuilderError.senderEqualsRecipient
        }
        if let encodedBounce = recipient.bounceable, encodedBounce != request.bounce {
            throw TonTransferTransactionBuilderError.bounceFlagMismatch
        }

        let amount = try parseAmount(request.amountNanotons)
        try validateSequenceNumber(request.sequenceNumber)
        let includesStateInit = request.includeStateInit ?? (request.sequenceNumber == 0)
        guard !includesStateInit || request.sequenceNumber == 0 else {
            throw TonTransferTransactionBuilderError.invalidStateInitPolicy
        }
        try validateExpiration(validUntil: request.validUntil, now: now)
        try validateComment(request.comment)

        let internalMessage = MessageRelaxed.internal(
            to: recipient.address,
            value: amount,
            bounce: request.bounce,
            body: try messageBody(comment: request.comment)
        )

        let transfer = try wallet.createTransfer(
            args: WalletTransferData(
                seqno: request.sequenceNumber,
                messages: [internalMessage],
                sendMode: .walletDefault(),
                timeout: request.validUntil
            )
        )
        let capturingSigner = TonCapturingTransferSigner(base: signer)
        let signedBody = try transfer.signMessage(signer: capturingSigner)
        guard let signingPayloadHash = capturingSigner.signingPayloadHash,
              signingPayloadHash.count == 32
        else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        let externalMessage = Message.external(
            to: walletAddress,
            stateInit: includesStateInit ? wallet.stateInit : nil,
            body: signedBody
        )
        let rootCell = try Builder().store(externalMessage).endCell()
        let boc = try TonCanonicalBoc.serialize(root: rootCell)
        guard !boc.isEmpty, boc.count <= maximumBocBytes else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }

        return TonExternalMessageEnvelope(
            boc: boc,
            bocBase64: boc.base64EncodedString(),
            messageHashHex: rootCell.hash().tonHexString,
            signingPayloadHashHex: signingPayloadHash.tonHexString,
            publicKey: publicKey,
            walletAddress: walletAddress.toString(
                urlSafe: true,
                testOnly: false,
                bounceable: false
            ),
            sequenceNumber: request.sequenceNumber,
            validUntil: request.validUntil,
            includesStateInit: includesStateInit
        )
    }

    static func requiredBounceFlag(forRecipientAddress value: String) throws -> Bool {
        let recipient = try parseAddress(value, role: .recipient)
        try validateMainnetAddress(recipient, role: .recipient)
        guard supportedRecipientWorkchains.contains(recipient.address.workchain) else {
            throw TonTransferTransactionBuilderError.unsupportedWorkchain
        }
        guard let bounceable = recipient.bounceable else {
            throw TonTransferTransactionBuilderError.ambiguousBounceFlag
        }
        return bounceable
    }

    private static func validateSupportedScope(
        asset: TonTransferAsset,
        network: TonTransferNetwork
    ) throws {
        guard asset == .nativeTon else {
            throw TonTransferTransactionBuilderError.unsupportedAsset
        }
        guard network == .mainnet else {
            throw TonTransferTransactionBuilderError.unsupportedNetwork
        }
    }

    private static func validatedPrivateKey(
        seed: Data
    ) throws -> Curve25519.Signing.PrivateKey {
        guard seed.count == privateKeyLength, seed.contains(where: { $0 != 0 }) else {
            throw TonTransferTransactionBuilderError.invalidPrivateKey
        }

        do {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        } catch {
            throw TonTransferTransactionBuilderError.invalidPrivateKey
        }
    }

    private static func validatePublicKey(_ publicKey: Data) throws {
        guard publicKey.count == publicKeyLength,
              publicKey.contains(where: { $0 != 0 }),
              (try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey)) != nil
        else {
            throw TonTransferTransactionBuilderError.invalidPublicKey
        }
    }

    private static func messageBody(comment: String?) throws -> Cell {
        guard let comment else {
            // TonSwift's `Cell.empty` convenience value is created with `Cell.init()`,
            // which does not precompute its hash/depth arrays. Finalize an empty
            // builder instead so callers can safely bind the body by hash.
            return try Builder().endCell()
        }
        return try Builder()
            .store(int: 0, bits: 32)
            .writeSnakeData(Data(comment.utf8))
            .endCell()
    }

    private static func parseAmount(_ value: String) throws -> BigUInt {
        let scalars = value.unicodeScalars
        guard !scalars.isEmpty,
              value.utf8.count <= maximumAmountDigits,
              scalars.allSatisfy({ (48 ... 57).contains($0.value) }),
              value == "0" || value.first != "0",
              let amount = BigUInt(value, radix: 10),
              amount > 0,
              amount <= maximumCoins
        else {
            throw TonTransferTransactionBuilderError.invalidAmount
        }

        return amount
    }

    private static func validateSequenceNumber(_ value: UInt64) throws {
        guard value <= UInt64(UInt32.max) else {
            throw TonTransferTransactionBuilderError.invalidSequenceNumber
        }
    }

    private static func validateExpiration(validUntil: UInt64, now: UInt64) throws {
        guard now <= UInt64(UInt32.max),
              validUntil <= UInt64(UInt32.max),
              validUntil > now
        else {
            throw TonTransferTransactionBuilderError.invalidExpiration
        }

        let lifetime = validUntil - now
        guard lifetime >= minimumLifetimeSeconds, lifetime <= maximumLifetimeSeconds else {
            throw TonTransferTransactionBuilderError.invalidExpiration
        }
    }

    private static func validateComment(_ comment: String?) throws {
        guard let comment else {
            return
        }

        guard !comment.isEmpty,
              comment.utf8.count <= maximumCommentBytes,
              !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Data(comment.utf8) == Data(comment.precomposedStringWithCanonicalMapping.utf8),
              !comment.unicodeScalars.contains(where: isForbiddenCommentScalar)
        else {
            throw TonTransferTransactionBuilderError.invalidComment
        }
    }

    private static func isForbiddenCommentScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control,
             .format,
             .lineSeparator,
             .paragraphSeparator,
             .surrogate,
             .privateUse,
             .unassigned:
            return true
        default:
            break
        }

        switch scalar.value {
        case 0 ... 31,
             127 ... 159,
             0x200B ... 0x200F,
             0x202A ... 0x202E,
             0x2060 ... 0x206F,
             0xFEFF:
            return true
        default:
            return false
        }
    }

    private static func validateMainnetAddress(
        _ address: ParsedTonAddress,
        role: AddressRole
    ) throws {
        if address.testOnly {
            throw TonTransferTransactionBuilderError.testnetAddressNotAllowed
        }
        guard address.address.hash.count == 32 else {
            throw role.invalidError
        }
    }

    private static func parseAddress(
        _ value: String,
        role: AddressRole
    ) throws -> ParsedTonAddress {
        guard !value.isEmpty,
              value.utf8.count <= maximumAddressInputBytes,
              value == value.trimmingCharacters(in: .whitespacesAndNewlines)
        else {
            throw role.invalidError
        }

        do {
            if value.contains(":") {
                let address = try TonSwift.Address.parse(raw: value)
                guard address.toRaw() == value else {
                    throw role.invalidError
                }
                return ParsedTonAddress(
                    address: address,
                    testOnly: false,
                    bounceable: nil
                )
            }

            guard value.unicodeScalars.allSatisfy({
                (45 ... 45).contains($0.value) ||
                    (48 ... 57).contains($0.value) ||
                    (65 ... 90).contains($0.value) ||
                    (95 ... 95).contains($0.value) ||
                    (97 ... 122).contains($0.value)
            }) else {
                throw role.invalidError
            }

            let standardBase64 = value
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            guard let bytes = Data(base64Encoded: standardBase64), bytes.count == 36 else {
                throw role.invalidError
            }

            let tag = bytes[0]
            let testOnly = tag & 0x80 != 0
            let addressTag = tag & 0x7F
            guard addressTag == 0x11 || addressTag == 0x51 else {
                throw role.invalidError
            }
            let bounceable = addressTag == 0x11
            let address = try TonSwift.Address.parse(value)
            let canonical = address.toString(
                urlSafe: true,
                testOnly: testOnly,
                bounceable: bounceable
            )
            guard canonical == value else {
                throw role.invalidError
            }

            return ParsedTonAddress(
                address: address,
                testOnly: testOnly,
                bounceable: bounceable
            )
        } catch let error as TonTransferTransactionBuilderError {
            throw error
        } catch {
            throw role.invalidError
        }
    }
}

private final class TonCapturingTransferSigner: WalletTransferSigner {
    private let base: WalletTransferSigner
    private(set) var signingPayloadHash: Data?

    init(base: WalletTransferSigner) {
        self.base = base
    }

    func signMessage(_ message: Data) throws -> Data {
        guard signingPayloadHash == nil else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        signingPayloadHash = message
        return try base.signMessage(message)
    }
}

private struct TonFixedSignatureSigner: WalletTransferSigner {
    let signature: Data

    func signMessage(_: Data) throws -> Data {
        guard signature.count == 64 else {
            throw TonTransferTransactionBuilderError.invalidSignature
        }
        return signature
    }
}

/// Deterministic single-root BOC serialization.
///
/// TonSwift's current topological sort selects the next cell from an unordered `Set`, which
/// makes multi-cell state-init BOCs process-seed dependent. This deliberately mirrors
/// `@ton/core`'s insertion-ordered breadth-first discovery and reverse-reference DFS so the
/// signed payload is deterministic and interoperable with the reference implementation.
private enum TonCanonicalBoc {
    private struct CellEntry {
        let cell: Cell
        let referenceHashes: [String]
    }

    static func serialize(root: Cell) throws -> Data {
        let cells = try sortedCells(root: root)
        let sizeBytes = byteWidth(UInt64(cells.count))
        let indexes = Dictionary(
            uniqueKeysWithValues: cells.enumerated().map { index, entry in
                (entry.cell.hash().tonHexString, UInt64(index))
            }
        )

        var cellData = Data()
        for entry in cells {
            guard entry.cell.refs.count <= RefsPerCell,
                  entry.cell.level <= 7
            else {
                throw TonTransferTransactionBuilderError.serializationFailed
            }

            let descriptorOne = UInt8(entry.cell.refs.count) +
                (entry.cell.isExotic ? 8 : 0) +
                UInt8(entry.cell.level) * 32
            let bitLength = entry.cell.bits.length
            let descriptorTwo = Int(ceil(Double(bitLength) / 8)) + bitLength / 8
            guard descriptorTwo <= Int(UInt8.max) else {
                throw TonTransferTransactionBuilderError.serializationFailed
            }

            cellData.append(descriptorOne)
            cellData.append(UInt8(descriptorTwo))
            cellData.append(entry.cell.bits.bitsToPaddedBuffer())
            for referenceHash in entry.referenceHashes {
                guard let referenceIndex = indexes[referenceHash] else {
                    throw TonTransferTransactionBuilderError.serializationFailed
                }
                cellData.append(encode(referenceIndex, byteCount: sizeBytes))
            }
        }

        let offsetBytes = byteWidth(UInt64(cellData.count))
        guard sizeBytes <= 7, offsetBytes <= Int(UInt8.max) else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }

        var result = Data([0xB5, 0xEE, 0x9C, 0x72])
        result.append(0x40 | UInt8(sizeBytes)) // CRC32C, no index/cache/flags.
        result.append(UInt8(offsetBytes))
        result.append(encode(UInt64(cells.count), byteCount: sizeBytes))
        result.append(encode(1, byteCount: sizeBytes))
        result.append(encode(0, byteCount: sizeBytes))
        result.append(encode(UInt64(cellData.count), byteCount: offsetBytes))
        result.append(encode(0, byteCount: sizeBytes)) // The root is always index zero.
        result.append(cellData)
        result.append(crc32c(result))
        return result
    }

    private static func sortedCells(root: Cell) throws -> [CellEntry] {
        var pending = [root]
        var entries: [String: CellEntry] = [:]
        var insertionOrder: [String] = []
        var notPermanent: Set<String> = []

        while !pending.isEmpty {
            let current = pending
            pending.removeAll(keepingCapacity: true)
            for cell in current {
                let hash = cell.hash().tonHexString
                guard entries[hash] == nil else {
                    continue
                }
                let references = cell.refs.map { $0.hash().tonHexString }
                entries[hash] = CellEntry(cell: cell, referenceHashes: references)
                insertionOrder.append(hash)
                notPermanent.insert(hash)
                pending.append(contentsOf: cell.refs)
            }
        }

        var temporary: Set<String> = []
        var sortedHashes: [String] = []

        func visit(_ hash: String) throws {
            guard notPermanent.contains(hash) else {
                return
            }
            guard !temporary.contains(hash), let entry = entries[hash] else {
                throw TonTransferTransactionBuilderError.serializationFailed
            }

            temporary.insert(hash)
            for reference in entry.referenceHashes.reversed() {
                try visit(reference)
            }
            sortedHashes.append(hash)
            temporary.remove(hash)
            notPermanent.remove(hash)
        }

        while let hash = insertionOrder.first(where: notPermanent.contains) {
            try visit(hash)
        }

        sortedHashes.reverse()
        guard sortedHashes.first == root.hash().tonHexString,
              sortedHashes.count == entries.count,
              notPermanent.isEmpty
        else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        return try sortedHashes.map { hash in
            guard let entry = entries[hash] else {
                throw TonTransferTransactionBuilderError.serializationFailed
            }
            return entry
        }
    }

    private static func byteWidth(_ value: UInt64) -> Int {
        guard value > 0 else {
            return 1
        }
        return max(1, (UInt64.bitWidth - value.leadingZeroBitCount + 7) / 8)
    }

    private static func encode(_ value: UInt64, byteCount: Int) -> Data {
        Data((0 ..< byteCount).map { offset in
            let shift = (byteCount - offset - 1) * 8
            return UInt8(truncatingIfNeeded: value >> UInt64(shift))
        })
    }

    private static func crc32c(_ data: Data) -> Data {
        let polynomial: UInt32 = 0x82F6_3B78
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0 ..< 8 {
                crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ polynomial
            }
        }
        crc ^= UInt32.max
        return Data([
            UInt8(truncatingIfNeeded: crc),
            UInt8(truncatingIfNeeded: crc >> 8),
            UInt8(truncatingIfNeeded: crc >> 16),
            UInt8(truncatingIfNeeded: crc >> 24)
        ])
    }
}

private enum AddressRole {
    case sender
    case recipient

    var invalidError: TonTransferTransactionBuilderError {
        switch self {
        case .sender:
            return .invalidSenderAddress
        case .recipient:
            return .invalidRecipientAddress
        }
    }
}

private struct ParsedTonAddress {
    let address: TonSwift.Address
    let testOnly: Bool
    let bounceable: Bool?
}

private extension Data {
    var tonHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
