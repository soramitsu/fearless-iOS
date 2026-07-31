import CryptoKit
@testable import fearless
import SoraKeystore
import TonSwift
import XCTest

final class TonPendingIntentJournalTests: XCTestCase {
    private static let now: UInt64 = 1_700_000_000
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let account = try! TonKeyDerivation.deriveAccount(mnemonic: mnemonic)
    private static let senderRaw = try! TonSwift.Address.parse(account.addressNonBounceable).toRaw()
    private static let recipientRaw = try! TonSwift.Address.parse(
        "EQAimhPwOYc5Z1JP_pddxo82SHOl67T0Lklw91pKtSX2Q094"
    ).toRaw()

    func testVersionedJournalRoundTripRebuildsExactBearerWithoutSecrets() throws {
        let pending = try makePending(emulated: true)
        let inspection = try TonTransferTransactionBuilder.inspectSignedMessage(
            pending.message.boc
        )
        XCTAssertEqual(inspection.messageHashHex, pending.message.messageHashHex)
        XCTAssertEqual(
            inspection.signingPayloadHashHex,
            pending.message.signingPayloadHashHex
        )

        let encoded = try TonPendingIntentJournalCodec.encode(pending)
        let decoded = try TonPendingIntentJournalCodec.decode(
            encoded,
            expectedSenderRaw: Self.senderRaw
        )

        XCTAssertEqual(decoded, pending)
        XCTAssertEqual(
            pending.feeQuote?.quoteIDHex,
            "0eb547b83019bdb5d66d62e35bc31053c00cbd68ba80599e9af1ccddd17e6958"
        )
        XCTAssertEqual(
            Data(SHA256.hash(data: encoded)).map { String(format: "%02x", $0) }.joined(),
            "3238980e4f69c2fdd20fa2666a713771b4bec2ee4154255f154f827679a05067"
        )
        XCTAssertLessThanOrEqual(encoded.count, TonPendingIntentJournalCodec.maximumRecordBytes)
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertFalse(text.contains(Self.mnemonic))
        XCTAssertFalse(text.contains(Self.account.privateKey.base64EncodedString()))
        XCTAssertTrue(text.contains(pending.message.messageHashHex))
        XCTAssertTrue(text.contains(pending.feeQuote!.quoteIDHex))

        var confirmed = pending
        confirmed.confirmed = true
        let confirmedData = try TonPendingIntentJournalCodec.encode(confirmed)
        XCTAssertTrue(String(decoding: confirmedData, as: UTF8.self).contains("\"phase\":\"confirmed\""))
        XCTAssertEqual(
            try TonPendingIntentJournalCodec.decode(
                confirmedData,
                expectedSenderRaw: Self.senderRaw
            ),
            confirmed
        )
    }

    func testCodecRejectsNoncanonicalCorruptAndCrossSenderRecords() throws {
        let encoded = try TonPendingIntentJournalCodec.encode(makePending(emulated: false))
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        let messageHash = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )["signedMessageHashHex"] as! String
        let quoteID = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )["quoteIDHex"] as! String

        let corruptions: [Data] = [
            Data(),
            Data(repeating: 0x41, count: TonPendingIntentJournalCodec.maximumRecordBytes + 1),
            Data("not-json".utf8),
            Data((" " + text).utf8),
            replacing(text, "\"schemaVersion\":1", with: "\"schemaVersion\":2"),
            replacing(text, "\"possiblyExposed\"", with: "\"unknownPhase123\""),
            replacing(text, "\"native-ton\"", with: "\"jettonxxxx\""),
            replacing(text, "\"mainnet\"", with: "\"testnet\""),
            replacing(text, Self.senderRaw, with: Self.recipientRaw),
            replacing(text, "\"amountNanotons\":\"100000000\"", with: "\"amountNanotons\":\"000000001\""),
            replacing(text, TonAPIClientFactory.canonicalAuthenticatedOrigin.absoluteString, with: "https://evil.example"),
            replacing(text, messageHash, with: "A" + messageHash.dropFirst()),
            replacing(text, quoteID, with: String(repeating: "0", count: 64)),
            replacing(text, "\"quotedFeeNanotons\":12345", with: "\"quotedFeeNanotons\":0"),
            replacingFirstBase64Byte(text, key: "signedBocBase64"),
            try replacingWithStructurallyValidInvalidSignature(text, pending: makePending(emulated: false)),
            replacingFirstBase64Byte(text, key: "unsignedBocBase64"),
            Data(text.dropLast().utf8)
        ]

        for (index, corruption) in corruptions.enumerated() {
            XCTAssertThrowsError(
                try TonPendingIntentJournalCodec.decode(
                    corruption,
                    expectedSenderRaw: Self.senderRaw
                ),
                "corruption \(index) unexpectedly decoded"
            ) { error in
                XCTAssertEqual(error as? TonPendingIntentJournalError, .corrupted)
            }
        }

        XCTAssertThrowsError(
            try TonPendingIntentJournalCodec.decode(
                encoded,
                expectedSenderRaw: Self.recipientRaw
            )
        ) { error in
            XCTAssertEqual(error as? TonPendingIntentJournalError, .corrupted)
        }
    }

    func testJournalConflictAndKeychainFailuresFailClosed() throws {
        let journal = TonInMemoryPendingIntentJournal()
        let first = try makePending(emulated: false)
        try journal.save(first)
        XCTAssertEqual(try journal.load(senderRaw: Self.senderRaw), first)

        var conflicting = first
        let alteredMessage = try TonTransferTransactionBuilder.buildAndSign(
            request: TonTransferTransactionRequest(
                senderAddress: Self.senderRaw,
                recipientAddress: Self.recipientRaw,
                amountNanotons: "100000001",
                sequenceNumber: 7,
                includeStateInit: false,
                validUntil: Self.now + 120,
                bounce: true,
                comment: "journal"
            ),
            privateKeySeed: Self.account.privateKey,
            now: Self.now
        )
        conflicting = TonPendingSignedIntent(
            identity: first.identity,
            intent: first.intent,
            message: alteredMessage,
            walletState: first.walletState,
            feeQuote: first.feeQuote,
            emulation: nil
        )
        XCTAssertThrowsError(try journal.save(conflicting)) { error in
            XCTAssertEqual(error as? TonPendingIntentJournalError, .conflict)
        }
        XCTAssertThrowsError(
            try journal.delete(
                senderRaw: Self.senderRaw,
                expectedMessageHashHex: String(repeating: "0", count: 64)
            )
        ) { error in
            XCTAssertEqual(error as? TonPendingIntentJournalError, .conflict)
        }

        let keychainJournal = TonKeychainPendingIntentJournal(
            keystore: AlwaysFailingKeystore()
        )
        XCTAssertThrowsError(try keychainJournal.load(senderRaw: Self.senderRaw)) { error in
            XCTAssertEqual(error as? TonPendingIntentJournalError, .unavailable)
        }
        XCTAssertThrowsError(try keychainJournal.save(first)) { error in
            XCTAssertEqual(error as? TonPendingIntentJournalError, .unavailable)
        }
        XCTAssertThrowsError(
            try keychainJournal.delete(
                senderRaw: Self.senderRaw,
                expectedMessageHashHex: first.message.messageHashHex
            )
        ) { error in
            XCTAssertEqual(error as? TonPendingIntentJournalError, .unavailable)
        }
    }

    private func makePending(emulated: Bool) throws -> TonPendingSignedIntent {
        let details = TonNativeSendRequest(
            mnemonic: Self.mnemonic,
            senderAddress: Self.senderRaw,
            recipientAddress: Self.recipientRaw,
            amountNanotons: "100000000",
            bounce: true,
            comment: "journal"
        )
        let identity = try TonTransferIntentIdentity(request: details)
        let intent = try TonEmulationIntent(request: details)
        let walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        let transaction = TonTransferTransactionRequest(
            senderAddress: identity.sender,
            recipientAddress: identity.recipient,
            amountNanotons: identity.amountNanotons,
            sequenceNumber: walletState.sequenceNumber,
            includeStateInit: false,
            validUntil: Self.now + 120,
            bounce: identity.bounce,
            comment: identity.comment
        )
        let unsigned = try TonTransferTransactionBuilder.buildForFeeEstimation(
            request: transaction,
            publicKey: Self.account.publicKey,
            now: Self.now
        )
        let quote = try TonTransferFeeQuote(
            templateCreatedAt: Self.now,
            issuedAt: Self.now,
            expiresAt: Self.now + 30,
            endpointOrigin: TonAPIClientFactory.canonicalAuthenticatedOrigin.absoluteString,
            publicKey: Self.account.publicKey,
            identity: identity,
            intent: intent,
            transactionRequest: transaction,
            walletState: walletState,
            unsignedMessage: unsigned,
            feeNanotons: 12_345
        )
        let signed = try TonTransferTransactionBuilder.buildAndSign(
            request: transaction,
            privateKeySeed: Self.account.privateKey,
            now: Self.now
        )
        return TonPendingSignedIntent(
            identity: identity,
            intent: intent,
            message: signed,
            walletState: walletState,
            feeQuote: quote,
            emulation: emulated
                ? TonEmulationResult(accepted: true, totalFeeNanotons: 12_345)
                : nil
        )
    }

    private func replacing(_ source: String, _ target: String, with replacement: String) -> Data {
        let mutated = source.replacingOccurrences(of: target, with: replacement)
        XCTAssertNotEqual(mutated, source, "mutation target missing: \(target)")
        return Data(mutated.utf8)
    }

    private func replacingFirstBase64Byte(_ source: String, key: String) -> Data {
        let object = try! JSONSerialization.jsonObject(with: Data(source.utf8)) as! [String: Any]
        let base64 = object[key] as! String
        let replacement = (base64.first == "A" ? "B" : "A") + base64.dropFirst()
        return replacing(source, base64, with: replacement)
    }

    private func replacingWithStructurallyValidInvalidSignature(
        _ source: String,
        pending: TonPendingSignedIntent
    ) throws -> Data {
        let quote = try XCTUnwrap(pending.feeQuote)
        let invalid = try TonTransferTransactionBuilder.rebuildSignedMessage(
            request: quote.transactionRequest,
            publicKey: quote.publicKey,
            signature: Data(repeating: 0, count: 64),
            now: quote.templateCreatedAt
        )
        let withBoc = source.replacingOccurrences(
            of: pending.message.bocBase64,
            with: invalid.bocBase64
        )
        let withHash = withBoc.replacingOccurrences(
            of: pending.message.messageHashHex,
            with: invalid.messageHashHex
        )
        XCTAssertNotEqual(withHash, source)
        return Data(withHash.utf8)
    }

    private final class AlwaysFailingKeystore: KeystoreProtocol {
        func addKey(_: Data, with _: String) throws { throw KeystoreError.unexpectedFail }
        func updateKey(_: Data, with _: String) throws { throw KeystoreError.unexpectedFail }
        func fetchKey(for _: String) throws -> Data { throw KeystoreError.unexpectedFail }
        func checkKey(for _: String) throws -> Bool { throw KeystoreError.unexpectedFail }
        func deleteKey(for _: String) throws { throw KeystoreError.unexpectedFail }
    }
}
