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
    case tonConnect
}

/// One standard TEP-74 transfer. There is no caller-controlled contract payload,
/// response address, attached TON amount, or forwarding amount.
struct TonJettonTransferDetails: Equatable, Hashable, Sendable {
    static let attachedNanotons = "640000000" // Released TON wallet attachment budget.
    let masterAddress: String
    let recipientAddress: String
    let amount: String

    init(masterAddress: String, recipientAddress: String, amount: String) throws {
        self.masterAddress = try TonTransferTransactionBuilder.canonicalMainnetAddress(masterAddress, basechainOnly: true)
        self.recipientAddress = try TonTransferTransactionBuilder.canonicalMainnetAddress(recipientAddress)
        _ = try TonTransferTransactionBuilder.parseAmount(amount)
        self.amount = amount
    }
}

enum TonTransferNetwork: String, Equatable, Hashable, Sendable, Codable {
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
    let jetton: TonJettonTransferDetails?
    let tonConnect: TonConnectTransferRequest?

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
        comment: String?,
        jetton: TonJettonTransferDetails? = nil,
        tonConnect: TonConnectTransferRequest? = nil
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
        self.jetton = jetton
        self.tonConnect = tonConnect
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
    static let maximumTonConnectBocBytes = 64 * 1024
    private static let maximumCoins = (BigUInt(1) << 120) - 1
    private static let supportedRecipientWorkchains: Set<Int8> = [0, -1]

    static func buildAndSign(
        request: TonTransferTransactionRequest,
        privateKeySeed: Data,
        now: UInt64
    ) throws -> TonSignedExternalMessage {
        do {
            try validateSupportedScope(asset: request.asset, network: request.network, jetton: request.jetton, tonConnect: request.tonConnect)
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
            try validateSupportedScope(asset: request.asset, network: request.network, jetton: request.jetton, tonConnect: request.tonConnect)
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
            try validateSupportedScope(asset: request.asset, network: request.network, jetton: request.jetton, tonConnect: request.tonConnect)
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
    static func inspectSignedMessage(_ boc: Data, tonConnect: TonConnectTransferRequest? = nil) throws -> TonSignedMessageInspection {
        let root = try parseBoundedBoc(boc, maximumBytes: tonConnect == nil ? maximumBocBytes : maximumTonConnectBocBytes)
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
        guard operation == 0, (1 ... 4).contains(bodySlice.remainingRefs),
              bodySlice.remainingRefs == (tonConnect?.messages.count ?? 1) else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        var inspected: [(info: CommonMsgInfoRelaxedInternal, body: Cell)] = []
        var total = BigUInt(0)
        for index in 0 ..< (tonConnect?.messages.count ?? 1) {
            let sendMode = try bodySlice.loadUint(bits: 8)
            guard sendMode == UInt64(SendMode.walletDefault().rawValue) else { throw TonTransferTransactionBuilderError.serializationFailed }
            let internalMessage = try MessageRelaxed.loadFrom(slice: bodySlice.loadRef().beginParse())
            guard case let .internalInfo(info) = internalMessage.info,
                  info.ihrDisabled, !info.bounced, try info.src.asInternal() == nil,
                  info.value.other.isEmpty, info.ihrFee.rawValue == 0, info.forwardFee.rawValue == 0,
                  info.createdLt == 0, info.createdAt == 0 else { throw TonTransferTransactionBuilderError.serializationFailed }
            if let expected = tonConnect?.messages[index] {
                let stateHash = try internalMessage.stateInit.map { try Builder().store($0).endCell().hash().tonHexString }
                let expectedBodyHash = try expected.payloadBocBase64.map { try tonConnectBoc($0).hash } ?? messageBodyHashHex(comment: nil)
                guard info.dest.toRaw() == expected.recipientAddress, info.value.coins.rawValue.description == expected.amountNanotons,
                      info.bounce == expected.bounce, stateHash == expected.stateInitHashHex,
                      internalMessage.body.hash().tonHexString == expectedBodyHash else { throw TonTransferTransactionBuilderError.serializationFailed }
            } else if internalMessage.stateInit != nil { throw TonTransferTransactionBuilderError.serializationFailed }
            inspected.append((info, internalMessage.body))
            total += info.value.coins.rawValue
        }
        try bodySlice.endParse()
        guard let first = inspected.first else { throw TonTransferTransactionBuilderError.serializationFailed }
        let internalInfo = first.info
        return TonSignedMessageInspection(
            messageHashHex: root.hash().tonHexString,
            signingPayloadHashHex: signingCell.hash().tonHexString,
            signature: signature,
            walletID: walletID,
            walletAddress: externalInfo.dest.toRaw(),
            recipientAddress: internalInfo.dest.toRaw(),
            amountNanotons: total.description,
            sequenceNumber: sequenceNumber,
            validUntil: validUntil,
            includesStateInit: externalMessage.stateInit != nil,
            bounce: internalInfo.bounce,
            messageBodyHashHex: try tonConnect.map { try $0.bindingHashHex() } ?? first.body.hash().tonHexString
        )
    }

    static func messageBodyHashHex(comment: String?) throws -> String {
        try validateComment(comment)
        return try messageBody(comment: comment).hash().tonHexString
    }

    static func canonicalMainnetAddress(_ value: String, basechainOnly: Bool = false) throws -> String {
        let parsed = try parseAddress(value, role: .recipient)
        try validateMainnetAddress(parsed, role: .recipient)
        guard (basechainOnly ? [Int8(0)] : [Int8(0), Int8(-1)]).contains(parsed.address.workchain) else {
            throw TonTransferTransactionBuilderError.unsupportedWorkchain
        }
        return parsed.address.toRaw()
    }

    static func messageBodyHashHex(comment: String?, jetton: TonJettonTransferDetails?, senderAddress: String) throws -> String {
        try validateComment(comment)
        return try messageBody(comment: comment, jetton: jetton, senderAddress: senderAddress).hash().tonHexString
    }

    private static func messageBody(comment: String?, jetton: TonJettonTransferDetails?, senderAddress: String) throws -> Cell {
        guard let jetton else { return try messageBody(comment: comment) }
        let recipient = try TonSwift.Address.parse(raw: jetton.recipientAddress)
        let sender = try TonSwift.Address.parse(raw: canonicalMainnetAddress(senderAddress, basechainOnly: true))
        guard recipient != sender else { throw TonTransferTransactionBuilderError.senderEqualsRecipient }
        guard let amount = Coins(rawValue: try parseAmount(jetton.amount)),
              let forward = Coins(rawValue: BigUInt(1)) else {
            throw TonTransferTransactionBuilderError.invalidAmount
        }
        let builder = try Builder()
            .store(uint: 0x0F8A_7EA5, bits: 32)
            .store(uint: 0, bits: 64)
            .store(amount)
            .store(recipient)
            .store(sender)
            .store(bit: false) // No custom payload.
            .store(forward)
        if let comment {
            // TEP-74 uses Either Cell ^Cell, not Maybe ^Cell after the discriminator.
            try builder.store(bit: true).store(ref: messageBody(comment: comment))
        } else {
            try builder.store(bit: false)
        }
        return try builder.endCell()
    }

    private static func build(
        request: TonTransferTransactionRequest,
        publicKey: Data,
        signer: WalletTransferSigner,
        now: UInt64
    ) throws -> TonExternalMessageEnvelope {
        if let tonConnect = request.tonConnect {
            return try buildTonConnect(tonConnect, transaction: request, publicKey: publicKey, signer: signer, now: now)
        }
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

        if let jetton = request.jetton {
            guard request.amountNanotons == TonJettonTransferDetails.attachedNanotons,
                  request.bounce, recipient.address.workchain == 0,
                  recipient.address.toRaw() != jetton.masterAddress
            else { throw TonTransferTransactionBuilderError.unsupportedAsset }
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
            body: try messageBody(comment: request.comment, jetton: request.jetton, senderAddress: request.senderAddress)
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

    static func validateSupportedScope(
        asset: TonTransferAsset, network: TonTransferNetwork,
        jetton: TonJettonTransferDetails? = nil, tonConnect: TonConnectTransferRequest? = nil
    ) throws {
        if let tonConnect {
            guard asset == .tonConnect, jetton == nil, network == tonConnect.network else {
                throw TonTransferTransactionBuilderError.unsupportedAsset
            }
            return
        }
        guard network == .mainnet else { throw TonTransferTransactionBuilderError.unsupportedNetwork }
        switch asset {
        case .nativeTon: guard jetton == nil else { throw TonTransferTransactionBuilderError.unsupportedAsset }
        case let .jetton(master): guard jetton?.masterAddress == master else { throw TonTransferTransactionBuilderError.unsupportedAsset }
        case .tonConnect: throw TonTransferTransactionBuilderError.unsupportedAsset
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

    static func parseAmount(_ value: String) throws -> BigUInt {
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
                  entry.cell.levelMask <= 7
            else {
                throw TonTransferTransactionBuilderError.serializationFailed
            }

            let descriptorOne = UInt8(entry.cell.refs.count) +
                (entry.cell.isExotic ? 8 : 0) +
                UInt8(entry.cell.levelMask) * 32
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

struct TonConnectTransferMessage: Equatable, Hashable, Sendable, Codable {
    let recipientAddress: String
    let amountNanotons: String
    let payloadBocBase64: String?
    let stateInitBocBase64: String?
    let payloadHashHex: String?
    let stateInitHashHex: String?
    let bounce: Bool
    let testOnly: Bool

    init(
        recipientAddress: String,
        amountNanotons: String,
        payloadBocBase64: String? = nil,
        stateInitBocBase64: String? = nil
    ) throws {
        let destination = try TonTransferTransactionBuilder.tonConnectAddress(recipientAddress)
        _ = try TonTransferTransactionBuilder.tonConnectAmount(amountNanotons)
        let payload = try payloadBocBase64.map { try TonTransferTransactionBuilder.tonConnectBoc($0) }
        let state = try stateInitBocBase64.map { try TonTransferTransactionBuilder.tonConnectBoc($0) }
        if let state {
            let slice = try state.cell.beginParse()
            _ = try StateInit.loadFrom(slice: slice)
            try slice.endParse()
            guard state.cell.hash() == (try TonSwift.Address.parse(raw: destination.raw)).hash else {
                throw TonTransferTransactionBuilderError.invalidRecipientAddress
            }
        }
        self.recipientAddress = destination.raw
        self.amountNanotons = amountNanotons
        self.payloadBocBase64 = payload?.base64
        self.stateInitBocBase64 = state?.base64
        payloadHashHex = payload?.hash
        stateInitHashHex = state?.hash
        bounce = destination.bounce
        testOnly = destination.testOnly
    }
}

struct TonConnectTransferRequest: Equatable, Hashable, Sendable, Codable {
    let publicKey: Data
    let senderAddress: String
    let network: TonTransferNetwork
    let validUntil: UInt64
    let replayIdentifier: String
    let messages: [TonConnectTransferMessage]
    let amountNanotons: String

    init(
        publicKey: Data,
        senderAddress: String,
        network: TonTransferNetwork,
        validUntil: UInt64,
        replayIdentifier: String,
        messages: [TonConnectTransferMessage]
    ) throws {
        guard (1 ... 4).contains(messages.count) else { throw TonTransferTransactionBuilderError.unsupportedAsset }
        guard !replayIdentifier.isEmpty, replayIdentifier.utf8.count <= 512,
              !replayIdentifier.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
            throw TonTransferTransactionBuilderError.unsupportedAsset
        }
        let sender = try TonTransferTransactionBuilder.tonConnectAddress(senderAddress)
        let rawSender = try TonSwift.Address.parse(raw: sender.raw)
        guard publicKey.count == 32, rawSender.workchain == 0,
              try WalletV4R2(publicKey: publicKey).address() == rawSender else {
            throw TonTransferTransactionBuilderError.senderKeyMismatch
        }
        if network == .mainnet, sender.testOnly || messages.contains(where: { $0.testOnly }) {
            throw TonTransferTransactionBuilderError.testnetAddressNotAllowed
        }
        guard validUntil > 0, validUntil <= UInt64(UInt32.max) else {
            throw TonTransferTransactionBuilderError.invalidExpiration
        }
        var total = BigUInt(0)
        var payloadBytes = 0
        for message in messages {
            total += try TonTransferTransactionBuilder.tonConnectAmount(message.amountNanotons)
            payloadBytes += message.payloadBocBase64?.utf8.count ?? 0
            payloadBytes += message.stateInitBocBase64?.utf8.count ?? 0
        }
        guard total <= BigUInt(Int64.max), payloadBytes <= 64 * 1024 else {
            throw TonTransferTransactionBuilderError.invalidAmount
        }
        self.publicKey = publicKey
        self.senderAddress = sender.raw
        self.network = network
        self.validUntil = validUntil
        self.replayIdentifier = replayIdentifier
        self.messages = messages
        amountNanotons = total.description
    }
}

extension TonTransferTransactionBuilder {
    static func tonConnectAddress(_ value: String) throws -> (raw: String, bounce: Bool, testOnly: Bool) {
        let parsed = try parseAddress(value, role: .recipient)
        guard parsed.address.hash.count == 32, [Int8(0), Int8(-1)].contains(parsed.address.workchain) else {
            throw TonTransferTransactionBuilderError.unsupportedWorkchain
        }
        return (parsed.address.toRaw(), parsed.bounceable ?? true, parsed.testOnly)
    }

    static func tonConnectAmount(_ value: String) throws -> BigUInt {
        if value == "0" { return BigUInt(0) }
        return try parseAmount(value)
    }

    static func tonConnectBoc(_ base64: String) throws -> (base64: String, hash: String, cell: Cell) {
        guard !base64.isEmpty, base64.utf8.count <= maximumTonConnectBocBytes * 2,
              let data = Data(base64Encoded: base64), data.base64EncodedString() == base64 else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        let cell = try parseBoundedBoc(data, maximumBytes: maximumTonConnectBocBytes)
        let canonical = try TonCanonicalBoc.serialize(root: cell)
        return (canonical.base64EncodedString(), cell.hash().tonHexString, cell)
    }

    /// TonSwift assumes its BOC reference/root indexes are in range. Check the wire
    /// structure before entering that parser, so malformed dapp input cannot trap.
    static func parseBoundedBoc(_ data: Data, maximumBytes: Int = maximumBocBytes) throws -> Cell {
        guard data.count >= 11, data.count <= maximumBytes else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        let bytes = Array(data)
        var cursor = 0
        func read(_ length: Int) throws -> Int {
            guard (1 ... 4).contains(length), cursor <= bytes.count - length else {
                throw TonTransferTransactionBuilderError.serializationFailed
            }
            var result = 0
            for _ in 0 ..< length { result = (result << 8) | Int(bytes[cursor]); cursor += 1 }
            return result
        }
        let magic = try read(4)
        guard [0xB5EE_9C72, 0x68FF_65F3, 0xACC3_A728].contains(magic) else { throw TonTransferTransactionBuilderError.serializationFailed }
        let flags = try read(1), offsetBytes = try read(1)
        let legacy = magic != 0xB5EE_9C72
        let indexPresent = legacy || flags & 0x80 != 0
        let crcPresent = legacy ? magic == 0xACC3_A728 : flags & 0x40 != 0
        let sizeBytes = legacy ? flags : flags & 7
        guard legacy || flags & 0x38 == 0, (1 ... 4).contains(sizeBytes), (1 ... 4).contains(offsetBytes) else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        let count = try read(sizeBytes), roots = try read(sizeBytes), absent = try read(sizeBytes)
        let cellBytes = try read(offsetBytes)
        guard (1 ... 4096).contains(count), roots == 1, absent == 0, cellBytes >= count * 2,
              cellBytes <= maximumBytes else { throw TonTransferTransactionBuilderError.serializationFailed }
        let root = legacy ? 0 : try read(sizeBytes)
        guard root < count else { throw TonTransferTransactionBuilderError.serializationFailed }
        if indexPresent {
            var previous = 0
            for _ in 0 ..< count {
                let index = try read(offsetBytes)
                guard index >= previous, index <= cellBytes else { throw TonTransferTransactionBuilderError.serializationFailed }
                previous = index
            }
        }
        let payloadStart = cursor
        guard payloadStart <= bytes.count - cellBytes,
              payloadStart + cellBytes + (crcPresent ? 4 : 0) == bytes.count else {
            throw TonTransferTransactionBuilderError.serializationFailed
        }
        let payloadEnd = payloadStart + cellBytes
        var references: [[Int]] = []
        for index in 0 ..< count {
            guard cursor <= payloadEnd - 2 else { throw TonTransferTransactionBuilderError.serializationFailed }
            let first = try read(1), second = try read(1)
            let refs = first & 7, size = (second + 1) / 2
            // Permit all four qualified exotic forms and their level masks. Stored-hash
            // descriptors are not decoded by the pinned SDK, so reject those explicitly.
            guard first & 0x10 == 0, refs <= 4, cursor <= payloadEnd - size - refs * sizeBytes else {
                throw TonTransferTransactionBuilderError.serializationFailed
            }
            if second & 1 != 0 {
                guard size > 0, bytes[cursor + size - 1] != 0, bytes[cursor + size - 1] != 0x80 else {
                    throw TonTransferTransactionBuilderError.serializationFailed
                }
            }
            if first & 8 != 0 {
                guard size >= 1, (1 ... 4).contains(Int(bytes[cursor])) else { throw TonTransferTransactionBuilderError.serializationFailed }
            }
            cursor += size
            var childIndexes: [Int] = []
            for _ in 0 ..< refs {
                let child = try read(sizeBytes)
                guard child > index, child < count else { throw TonTransferTransactionBuilderError.serializationFailed }
                childIndexes.append(child)
            }
            references.append(childIndexes)
        }
        guard cursor == payloadEnd else { throw TonTransferTransactionBuilderError.serializationFailed }
        var depths = Array(repeating: 0, count: count)
        for index in (0 ..< count).reversed() {
            depths[index] = (references[index].map { depths[$0] }.max() ?? -1) + 1
            guard depths[index] <= 128 else { throw TonTransferTransactionBuilderError.serializationFailed }
        }
        let parsed = try Cell.fromBoc(src: data) // CRC is checked by TonSwift after bounded preflight.
        guard parsed.count == 1 else { throw TonTransferTransactionBuilderError.serializationFailed }
        return parsed[0]
    }
}

extension TonTransferTransactionBuilder {
    private static func buildTonConnect(
        _ connect: TonConnectTransferRequest, transaction: TonTransferTransactionRequest,
        publicKey: Data, signer: WalletTransferSigner, now: UInt64
    ) throws -> TonExternalMessageEnvelope {
        _ = try TonConnectTransferRequest.decodeCanonical(connect.canonicalData())
        guard transaction.asset == .tonConnect, transaction.network == connect.network,
              transaction.jetton == nil, transaction.comment == nil,
              transaction.senderAddress == connect.senderAddress,
              transaction.recipientAddress == connect.messages[0].recipientAddress,
              transaction.amountNanotons == connect.amountNanotons,
              transaction.bounce == connect.messages[0].bounce,
              transaction.validUntil == connect.validUntil,
              publicKey == connect.publicKey else { throw TonTransferTransactionBuilderError.senderKeyMismatch }
        try validateSequenceNumber(transaction.sequenceNumber)
        guard connect.validUntil > now, connect.validUntil - now >= minimumLifetimeSeconds else {
            throw TonTransferTransactionBuilderError.invalidExpiration
        }
        let includeState = transaction.includeStateInit ?? (transaction.sequenceNumber == 0)
        guard !includeState || transaction.sequenceNumber == 0 else { throw TonTransferTransactionBuilderError.invalidStateInitPolicy }
        let wallet = WalletV4R2(workchain: 0, publicKey: publicKey)
        let address = try wallet.address()
        let messages = try connect.messages.map { message -> MessageRelaxed in
            let state = try message.stateInitBocBase64.map { value -> StateInit in
                let slice = try tonConnectBoc(value).cell.beginParse()
                let result = try StateInit.loadFrom(slice: slice)
                try slice.endParse()
                return result
            }
            let body = try message.payloadBocBase64.map { try tonConnectBoc($0).cell } ?? messageBody(comment: nil)
            return .internal(
                to: try TonSwift.Address.parse(raw: message.recipientAddress),
                value: try tonConnectAmount(message.amountNanotons),
                bounce: message.bounce,
                stateInit: state,
                body: body
            )
        }
        let transfer = try wallet.createTransfer(args: WalletTransferData(
            seqno: transaction.sequenceNumber, messages: messages, sendMode: .walletDefault(), timeout: connect.validUntil
        ))
        let capturing = TonCapturingTransferSigner(base: signer)
        let signed = try transfer.signMessage(signer: capturing)
        guard let hash = capturing.signingPayloadHash, hash.count == 32 else { throw TonTransferTransactionBuilderError.serializationFailed }
        let external = Message.external(to: address, stateInit: includeState ? wallet.stateInit : nil, body: signed)
        let root = try Builder().store(external).endCell()
        let boc = try TonCanonicalBoc.serialize(root: root)
        guard boc.count <= maximumTonConnectBocBytes else { throw TonTransferTransactionBuilderError.serializationFailed }
        return TonExternalMessageEnvelope(
            boc: boc, bocBase64: boc.base64EncodedString(), messageHashHex: root.hash().tonHexString,
            signingPayloadHashHex: hash.tonHexString, publicKey: publicKey,
            walletAddress: address.toString(urlSafe: true, testOnly: connect.network == .testnet, bounceable: false),
            sequenceNumber: transaction.sequenceNumber, validUntil: connect.validUntil, includesStateInit: includeState
        )
    }
}

extension TonConnectTransferRequest {
    func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    static func decodeCanonical(_ data: Data) throws -> TonConnectTransferRequest {
        guard data.count <= 96 * 1024 else { throw TonTransferTransactionBuilderError.serializationFailed }
        let decoded = try JSONDecoder().decode(Self.self, from: data)
        let messages = try decoded.messages.map { original -> TonConnectTransferMessage in
            let address = try TonSwift.Address.parse(raw: original.recipientAddress)
            let validated = try TonConnectTransferMessage(
                recipientAddress: address.toString(urlSafe: true, testOnly: original.testOnly, bounceable: original.bounce),
                amountNanotons: original.amountNanotons,
                payloadBocBase64: original.payloadBocBase64, stateInitBocBase64: original.stateInitBocBase64
            )
            guard validated == original else { throw TonTransferTransactionBuilderError.serializationFailed }
            return validated
        }
        let validated = try Self(
            publicKey: decoded.publicKey,
            senderAddress: decoded.senderAddress,
            network: decoded.network,
            validUntil: decoded.validUntil,
            replayIdentifier: decoded.replayIdentifier,
            messages: messages
        )
        guard validated == decoded, try validated.canonicalData() == data else { throw TonTransferTransactionBuilderError.serializationFailed }
        return validated
    }

    func bindingHashHex() throws -> String {
        Data(SHA256.hash(data: try canonicalData())).tonHexString
    }
}
