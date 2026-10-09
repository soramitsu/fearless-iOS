import CryptoKit
import Foundation
import SoraKeystore
import TonSwift

enum TonPendingIntentJournalError: Error, Equatable {
    case unavailable
    case corrupted
    case conflict
}

protocol TonPendingIntentJournaling: Sendable {
    func load(senderRaw: String) throws -> TonPendingSignedIntent?
    func save(_ pending: TonPendingSignedIntent) throws
    func delete(senderRaw: String, expectedMessageHashHex: String) throws
}

private extension TonPendingSignedIntent {
    var journalPhaseRank: Int {
        if confirmed {
            return 2
        }
        return emulation == nil ? 0 : 1
    }

    func hasSameBearer(as other: TonPendingSignedIntent) -> Bool {
        identity == other.identity &&
            intent == other.intent &&
            message == other.message &&
            walletState == other.walletState &&
            feeQuote == other.feeQuote
    }
}

/// Thread-safe test/local store. Production uses `TonKeychainPendingIntentJournal`.
final class TonInMemoryPendingIntentJournal: TonPendingIntentJournaling, @unchecked Sendable {
    private let lock = NSLock()
    private var pendingBySender: [String: TonPendingSignedIntent] = [:]

    func load(senderRaw: String) throws -> TonPendingSignedIntent? {
        lock.lock()
        defer { lock.unlock() }
        return pendingBySender[senderRaw]
    }

    func save(_ pending: TonPendingSignedIntent) throws {
        lock.lock()
        defer { lock.unlock() }
        if let existing = pendingBySender[pending.identity.sender] {
            guard pending.hasSameBearer(as: existing),
                  pending.journalPhaseRank >= existing.journalPhaseRank
            else {
                throw TonPendingIntentJournalError.conflict
            }
        }
        pendingBySender[pending.identity.sender] = pending
    }

    func delete(senderRaw: String, expectedMessageHashHex: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let existing = pendingBySender[senderRaw] else {
            return
        }
        guard existing.message.messageHashHex == expectedMessageHashHex else {
            throw TonPendingIntentJournalError.conflict
        }
        pendingBySender.removeValue(forKey: senderRaw)
    }
}

/// Device-local, non-migrating storage for an already-signed bearer BOC. No mnemonic,
/// passphrase, seed, or private key is ever encoded in this record.
final class TonKeychainPendingIntentJournal: TonPendingIntentJournaling, @unchecked Sendable {
    private static let identifierPrefix = "jp.co.soramitsu.fearless.ton.pending.v1."
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol = Keychain()) {
        self.keystore = keystore
    }

    func load(senderRaw: String) throws -> TonPendingSignedIntent? {
        let identifier = try keyIdentifier(senderRaw: senderRaw)
        do {
            guard try keystore.checkKey(for: identifier) else {
                return nil
            }
            let data = try keystore.fetchKey(for: identifier)
            return try TonPendingIntentJournalCodec.decode(
                data,
                expectedSenderRaw: senderRaw
            )
        } catch let error as TonPendingIntentJournalError {
            throw error
        } catch KeystoreError.noKeyFound {
            return nil
        } catch {
            throw TonPendingIntentJournalError.unavailable
        }
    }

    func save(_ pending: TonPendingSignedIntent) throws {
        let identifier = try keyIdentifier(senderRaw: pending.identity.sender)
        if let existing = try load(senderRaw: pending.identity.sender) {
            guard pending.hasSameBearer(as: existing),
                  pending.journalPhaseRank >= existing.journalPhaseRank
            else {
                throw TonPendingIntentJournalError.conflict
            }
        }
        let data = try TonPendingIntentJournalCodec.encode(pending)
        do {
            try keystore.saveKey(data, with: identifier)
        } catch {
            throw TonPendingIntentJournalError.unavailable
        }
    }

    func delete(senderRaw: String, expectedMessageHashHex: String) throws {
        let identifier = try keyIdentifier(senderRaw: senderRaw)
        guard let existing = try load(senderRaw: senderRaw) else {
            return
        }
        guard existing.message.messageHashHex == expectedMessageHashHex else {
            throw TonPendingIntentJournalError.conflict
        }
        do {
            try keystore.deleteKey(for: identifier)
        } catch KeystoreError.noKeyFound {
            return
        } catch {
            throw TonPendingIntentJournalError.unavailable
        }
    }

    private func keyIdentifier(senderRaw: String) throws -> String {
        guard let address = try? TonSwift.Address.parse(raw: senderRaw),
              address.toRaw() == senderRaw,
              address.workchain == 0
        else {
            throw TonPendingIntentJournalError.corrupted
        }
        let digest = Data(SHA256.hash(data: Data(senderRaw.utf8)))
            .map { String(format: "%02x", $0) }
            .joined()
        return Self.identifierPrefix + digest
    }
}

enum TonPendingIntentJournalCodec {
    static let maximumRecordBytes = 48 * 1024
    private static let schemaVersion: UInt8 = 1

    private struct Record: Codable {
        let schemaVersion: UInt8
        let phase: String
        let asset: String
        let network: String
        let senderRaw: String
        let recipientRaw: String
        let amountNanotons: String
        let bounce: Bool
        let comment: String?
        let publicKeyBase64: String
        let walletSequenceNumber: UInt64
        let walletIsInitialized: Bool
        let templateCreatedAt: UInt64
        let quoteIssuedAt: UInt64
        let quoteExpiresAt: UInt64
        let quoteEndpointOrigin: String
        let quoteIDHex: String
        let quotedFeeNanotons: UInt64
        let unsignedBocBase64: String
        let signedBocBase64: String
        let signedMessageHashHex: String
        let signedEmulationAccepted: Bool?
        let signedEmulationFeeNanotons: UInt64?
    }

    static func encode(_ pending: TonPendingSignedIntent) throws -> Data {
        guard let quote = pending.feeQuote else {
            throw TonPendingIntentJournalError.corrupted
        }
        let phase: String
        let accepted: Bool?
        let fee: UInt64?
        if pending.confirmed {
            phase = "confirmed"
            if let emulation = pending.emulation {
                guard emulation.accepted,
                      emulation.totalFeeNanotons == quote.feeNanotons
                else {
                    throw TonPendingIntentJournalError.corrupted
                }
                accepted = true
                fee = emulation.totalFeeNanotons
            } else {
                accepted = nil
                fee = nil
            }
        } else if let emulation = pending.emulation {
            guard emulation.accepted,
                  emulation.totalFeeNanotons == quote.feeNanotons
            else {
                throw TonPendingIntentJournalError.corrupted
            }
            phase = "emulated"
            accepted = true
            fee = emulation.totalFeeNanotons
        } else {
            phase = "possiblyExposed"
            accepted = nil
            fee = nil
        }

        let record = Record(
            schemaVersion: schemaVersion,
            phase: phase,
            asset: "native-ton",
            network: "mainnet",
            senderRaw: pending.identity.sender,
            recipientRaw: pending.identity.recipient,
            amountNanotons: pending.identity.amountNanotons,
            bounce: pending.identity.bounce,
            comment: pending.identity.comment,
            publicKeyBase64: quote.publicKey.base64EncodedString(),
            walletSequenceNumber: pending.walletState.sequenceNumber,
            walletIsInitialized: pending.walletState.isInitialized,
            templateCreatedAt: quote.templateCreatedAt,
            quoteIssuedAt: quote.issuedAt,
            quoteExpiresAt: quote.expiresAt,
            quoteEndpointOrigin: quote.endpointOrigin,
            quoteIDHex: quote.quoteIDHex,
            quotedFeeNanotons: quote.feeNanotons,
            unsignedBocBase64: quote.unsignedMessage.bocBase64,
            signedBocBase64: pending.message.bocBase64,
            signedMessageHashHex: pending.message.messageHashHex,
            signedEmulationAccepted: accepted,
            signedEmulationFeeNanotons: fee
        )
        let data = try canonicalEncoder().encode(record)
        guard !data.isEmpty, data.count <= maximumRecordBytes else {
            throw TonPendingIntentJournalError.corrupted
        }
        // Encode is also a validation boundary, not merely serialization.
        _ = try decode(data, expectedSenderRaw: pending.identity.sender)
        return data
    }

    static func decode(
        _ data: Data,
        expectedSenderRaw: String
    ) throws -> TonPendingSignedIntent {
        do {
            guard !data.isEmpty, data.count <= maximumRecordBytes else {
                throw TonPendingIntentJournalError.corrupted
            }
            let record = try JSONDecoder().decode(Record.self, from: data)
            guard try canonicalEncoder().encode(record) == data,
                  record.schemaVersion == schemaVersion,
                  record.asset == "native-ton",
                  record.network == "mainnet",
                  record.senderRaw == expectedSenderRaw,
                  isLowercaseHash(record.quoteIDHex),
                  isLowercaseHash(record.signedMessageHashHex)
            else {
                throw TonPendingIntentJournalError.corrupted
            }

            let publicKey = try decodeCanonicalBase64(record.publicKeyBase64)
            let unsignedBoc = try decodeCanonicalBase64(record.unsignedBocBase64)
            let signedBoc = try decodeCanonicalBase64(record.signedBocBase64)
            guard publicKey.count == 32,
                  publicKey.contains(where: { $0 != 0 }),
                  !unsignedBoc.isEmpty,
                  unsignedBoc.count <= TonTransferTransactionBuilder.maximumBocBytes,
                  !signedBoc.isEmpty,
                  signedBoc.count <= TonTransferTransactionBuilder.maximumBocBytes,
                  let sender = try? TonSwift.Address.parse(raw: record.senderRaw),
                  sender.toRaw() == record.senderRaw,
                  sender.workchain == 0,
                  let recipient = try? TonSwift.Address.parse(raw: record.recipientRaw),
                  recipient.toRaw() == record.recipientRaw,
                  [Int8(0), Int8(-1)].contains(recipient.workchain),
                  sender != recipient
            else {
                throw TonPendingIntentJournalError.corrupted
            }
            let wallet = WalletV4R2(workchain: 0, publicKey: publicKey)
            guard try wallet.address() == sender else {
                throw TonPendingIntentJournalError.corrupted
            }

            let requestDetails = TonNativeSendRequest(
                mnemonic: "",
                senderAddress: record.senderRaw,
                recipientAddress: record.recipientRaw,
                amountNanotons: record.amountNanotons,
                bounce: record.bounce,
                comment: record.comment
            )
            let identity = try TonTransferIntentIdentity(request: requestDetails)
            let intent = try TonEmulationIntent(request: requestDetails)
            let walletState = TonWalletRemoteState(
                sequenceNumber: record.walletSequenceNumber,
                isInitialized: record.walletIsInitialized
            )
            guard walletState.isInitialized || walletState.sequenceNumber == 0 else {
                throw TonPendingIntentJournalError.corrupted
            }
            let transactionRequest = TonTransferTransactionRequest(
                senderAddress: identity.sender,
                recipientAddress: identity.recipient,
                amountNanotons: identity.amountNanotons,
                sequenceNumber: walletState.sequenceNumber,
                includeStateInit: !walletState.isInitialized,
                validUntil: try signedValidUntil(signedBoc),
                bounce: identity.bounce,
                comment: identity.comment
            )

            let rebuiltUnsigned = try TonTransferTransactionBuilder.buildForFeeEstimation(
                request: transactionRequest,
                publicKey: publicKey,
                now: record.templateCreatedAt
            )
            guard rebuiltUnsigned.boc == unsignedBoc else {
                throw TonPendingIntentJournalError.corrupted
            }
            let quote = try TonTransferFeeQuote(
                expectedQuoteIDHex: record.quoteIDHex,
                templateCreatedAt: record.templateCreatedAt,
                issuedAt: record.quoteIssuedAt,
                expiresAt: record.quoteExpiresAt,
                endpointOrigin: record.quoteEndpointOrigin,
                publicKey: publicKey,
                identity: identity,
                intent: intent,
                transactionRequest: transactionRequest,
                walletState: walletState,
                unsignedMessage: rebuiltUnsigned,
                feeNanotons: record.quotedFeeNanotons
            )

            let inspection = try TonTransferTransactionBuilder.inspectSignedMessage(signedBoc)
            guard inspection.messageHashHex == record.signedMessageHashHex,
                  inspection.walletAddress == identity.sender,
                  inspection.recipientAddress == identity.recipient,
                  inspection.amountNanotons == identity.amountNanotons,
                  inspection.sequenceNumber == walletState.sequenceNumber,
                  inspection.validUntil == transactionRequest.validUntil,
                  inspection.includesStateInit == !walletState.isInitialized,
                  inspection.bounce == identity.bounce,
                  inspection.messageBodyHashHex == intent.messageBodyHashHex,
                  let signingHash = strictHexData(inspection.signingPayloadHashHex),
                  signingHash.count == 32,
                  try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
                  .isValidSignature(inspection.signature, for: signingHash)
            else {
                throw TonPendingIntentJournalError.corrupted
            }
            let rebuiltSigned = try TonTransferTransactionBuilder.rebuildSignedMessage(
                request: transactionRequest,
                publicKey: publicKey,
                signature: inspection.signature,
                now: record.templateCreatedAt
            )
            guard rebuiltSigned.boc == signedBoc,
                  rebuiltSigned.messageHashHex == record.signedMessageHashHex,
                  rebuiltSigned.signingPayloadHashHex == quote.unsignedMessage.signingPayloadHashHex
            else {
                throw TonPendingIntentJournalError.corrupted
            }

            let emulation: TonEmulationResult?
            let confirmed: Bool
            switch record.phase {
            case "possiblyExposed":
                guard record.signedEmulationAccepted == nil,
                      record.signedEmulationFeeNanotons == nil
                else {
                    throw TonPendingIntentJournalError.corrupted
                }
                emulation = nil
                confirmed = false
            case "emulated":
                guard record.signedEmulationAccepted == true,
                      record.signedEmulationFeeNanotons == quote.feeNanotons
                else {
                    throw TonPendingIntentJournalError.corrupted
                }
                emulation = TonEmulationResult(
                    accepted: true,
                    totalFeeNanotons: record.signedEmulationFeeNanotons
                )
                confirmed = false
            case "confirmed":
                if record.signedEmulationAccepted == nil,
                   record.signedEmulationFeeNanotons == nil {
                    emulation = nil
                } else {
                    guard record.signedEmulationAccepted == true,
                          record.signedEmulationFeeNanotons == quote.feeNanotons
                    else {
                        throw TonPendingIntentJournalError.corrupted
                    }
                    emulation = TonEmulationResult(
                        accepted: true,
                        totalFeeNanotons: record.signedEmulationFeeNanotons
                    )
                }
                confirmed = true
            default:
                throw TonPendingIntentJournalError.corrupted
            }

            return TonPendingSignedIntent(
                identity: identity,
                intent: intent,
                message: rebuiltSigned,
                walletState: walletState,
                feeQuote: quote,
                emulation: emulation,
                confirmed: confirmed
            )
        } catch let error as TonPendingIntentJournalError {
            throw error
        } catch {
            throw TonPendingIntentJournalError.corrupted
        }
    }

    private static func signedValidUntil(_ boc: Data) throws -> UInt64 {
        try TonTransferTransactionBuilder.inspectSignedMessage(boc).validUntil
    }

    private static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func decodeCanonicalBase64(_ value: String) throws -> Data {
        guard !value.isEmpty,
              value.utf8.count <= maximumRecordBytes * 2,
              let data = Data(base64Encoded: value),
              data.base64EncodedString() == value
        else {
            throw TonPendingIntentJournalError.corrupted
        }
        return data
    }

    private static func isLowercaseHash(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { byte in
            (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
        }
    }

    private static func strictHexData(_ value: String) -> Data? {
        guard value.utf8.count.isMultiple(of: 2),
              value.utf8.allSatisfy({ byte in
                  (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
              })
        else {
            return nil
        }
        var result = Data()
        result.reserveCapacity(value.utf8.count / 2)
        let bytes = Array(value.utf8)
        for index in stride(from: 0, to: bytes.count, by: 2) {
            func nibble(_ byte: UInt8) -> UInt8 {
                byte <= 57 ? byte - 48 : byte - 87
            }
            result.append(nibble(bytes[index]) << 4 | nibble(bytes[index + 1]))
        }
        return result
    }
}
