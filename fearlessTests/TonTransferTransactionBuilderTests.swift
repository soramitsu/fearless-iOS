import CryptoKit
import Foundation
import HTTPTypes
import OpenAPIRuntime
import TonAPI
import TonSwift
import XCTest

@testable import fearless

final class TonTransferTransactionBuilderTests: XCTestCase {
    private static let now: UInt64 = 1_680_178_900
    private static let validUntil: UInt64 = 1_680_179_023
    private static let privateKey = Data(hexString: "34aebb9ea454967f16c407c0f8877763e86212116468169d93a3dcbcafe530c9")!
    private static let sender = "UQDnBF4JTFKHTYjulEJyNd4dstLGH1m51UrLdu01_tw4zz3r"
    private static let recipient = "EQAimhPwOYc5Z1JP_pddxo82SHOl67T0Lklw91pKtSX2Q094"

    func testBuildsCanonicalWalletV4R2ExternalMessageGoldenVector() throws {
        let result = try build()

        XCTAssertEqual(result.walletAddress, Self.sender)
        XCTAssertEqual(result.sequenceNumber, 62)
        XCTAssertEqual(result.validUntil, Self.validUntil)
        XCTAssertFalse(result.includesStateInit)
        XCTAssertEqual(result.bocBase64, "te6cckEBAgEAugAB4YgBzgi8EpilDpsR3SiE5Gu8O2WljD6zc6qVlu3aa/24cZ4AEoDsU2T7wDyTVijEInQfjlDd9yoM2JuJ+WH7lEOWTtcSYClvJKkLv3VQWPcDAYFxj3mA5C78TtoReTfu+qKIeU1NGLshK/p4AAAB8AAcAQCIYgARTQn4HMOcs6kn/0uu40ebJDnS9dp6FyS4e60lWpL7IaAvrwgAAAAAAAAAAAAAAAAAAAAAAABGZWFybGVzcyBUT076wCvr")
        XCTAssertEqual(result.boc.count, 201)
        XCTAssertEqual(Data(SHA256.hash(data: result.boc)).hexString, "8c1137afabb6d0c817867997c0ba74169c42b39bc6f99ba5d7e62d839f7f47a6")
        XCTAssertEqual(result.messageHashHex, "25bdaa831cfc4f67550585691850fcf10b52875682f431a97935346942af07b2")
    }

    func testSequenceZeroIncludesStateInitAndProducesStableDeploymentMessage() throws {
        let result = try build(
            request: makeRequest(sequenceNumber: 0, comment: nil)
        )

        XCTAssertTrue(result.includesStateInit)
        // Generated independently with @ton/core 0.63.1 using the same deterministic
        // Ed25519 seed and reserialized with { idx: false, crc32: true }.
        XCTAssertEqual(result.boc.count, 956)
        XCTAssertEqual(Data(result.boc.prefix(16)).hexString, "b5ee9c72410217010003ac0003e38801")
        XCTAssertEqual(Data(SHA256.hash(data: result.boc)).hexString, "a5876cf00a39808e90fe70a9c32b1047fa9a71b8348265ebc43941bd08e9e888")
        XCTAssertEqual(result.messageHashHex, "6a098be18f97f763e4467ea8ae24826e2270babfa7ad7c7489d79e841a3a38e4")
        let roots = try Cell.fromBoc(src: result.boc)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].hash().hexString, result.messageHashHex)
    }

    func testVerifiedInitializedWalletAtSequenceZeroCanOmitStateInit() throws {
        let result = try build(
            request: makeRequest(
                sequenceNumber: 0,
                includeStateInit: false,
                comment: nil
            )
        )

        XCTAssertFalse(result.includesStateInit)
    }

    func testFeeEstimationMessageHasCompileTimeDistinctInvalidSignature() throws {
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: Self.privateKey)
        let result = try TonTransferTransactionBuilder.buildForFeeEstimation(
            request: makeRequest(),
            publicKey: privateKey.publicKey.rawRepresentation,
            now: Self.now
        )
        let root = try XCTUnwrap(Cell.fromBoc(src: result.boc).first)
        let externalMessage = try Message.loadFrom(slice: root.beginParse())
        let body = try externalMessage.body.beginParse()
        let signature = try body.loadBytes(64)
        let signingMessage = try body.loadRemainder()

        XCTAssertEqual(signature, Data(repeating: 0x30, count: 64))
        XCTAssertFalse(
            privateKey.publicKey.isValidSignature(
                signature,
                for: signingMessage.hash()
            )
        )
    }

    func testNilCommentUsesCanonicalHashableEmptyMessageBody() throws {
        XCTAssertEqual(
            try TonTransferTransactionBuilder.messageBodyHashHex(comment: nil),
            "96a296d224f285c67bee93c30f8a309157f0daa35dc5b87e410b78630a09cfc7"
        )
    }

    func testDeploymentRootHashAndSemanticsStayStableAcrossRepeatedBuilds() throws {
        var hashes = Set<String>()
        for _ in 0 ..< 100 {
            let result = try build(request: makeRequest(sequenceNumber: 0, comment: nil))
            let roots = try Cell.fromBoc(src: result.boc)
            XCTAssertEqual(roots.count, 1)
            XCTAssertEqual(roots[0].hash().hexString, result.messageHashHex)
            XCTAssertTrue(result.includesStateInit)
            hashes.insert(result.messageHashHex)
        }

        XCTAssertEqual(hashes, ["6a098be18f97f763e4467ea8ae24826e2270babfa7ad7c7489d79e841a3a38e4"])
    }

    func testCanonicalRawRecipientIsAcceptedWithoutNetworkOrBounceAmbiguity() throws {
        let rawRecipient = try TonSwift.Address.parse(Self.recipient).toRaw()
        let result = try build(
            request: makeRequest(recipientAddress: rawRecipient)
        )

        XCTAssertFalse(result.boc.isEmpty)
    }

    func testRejectsUnsupportedJettonAndTestnetScopeBeforeKeyOrAddressParsing() {
        assertError(
            .unsupportedAsset,
            request: makeRequest(
                asset: .jetton(masterAddress: "malformed-master"),
                senderAddress: "malformed-sender",
                recipientAddress: "malformed-recipient"
            ),
            privateKey: Data()
        )
        assertError(
            .unsupportedNetwork,
            request: makeRequest(
                network: .testnet,
                senderAddress: "malformed-sender",
                recipientAddress: "malformed-recipient"
            ),
            privateKey: Data()
        )
    }

    func testRequiresExplicitBouncePolicyForRawRecipientAtServiceBoundary() throws {
        let rawRecipient = try TonSwift.Address.parse(Self.recipient).toRaw()

        XCTAssertThrowsError(
            try TonTransferTransactionBuilder.requiredBounceFlag(forRecipientAddress: rawRecipient)
        ) { error in
            XCTAssertEqual(error as? TonTransferTransactionBuilderError, .ambiguousBounceFlag)
        }
        XCTAssertTrue(
            try TonTransferTransactionBuilder.requiredBounceFlag(forRecipientAddress: Self.recipient)
        )
    }

    func testRejectsMalformedZeroAndWrongLengthPrivateKeys() {
        let invalidKeys = [
            Data(),
            Data(repeating: 1, count: 31),
            Data(repeating: 1, count: 33),
            Data(repeating: 0, count: 32)
        ]

        invalidKeys.forEach { key in
            assertError(.invalidPrivateKey, privateKey: key)
        }
    }

    func testRejectsSenderThatDoesNotMatchSigningKey() throws {
        let otherKey = Curve25519.Signing.PrivateKey()
        let otherAddress = try WalletV4R2(
            workchain: 0,
            publicKey: otherKey.publicKey.rawRepresentation
        ).address().toString(urlSafe: true, testOnly: false, bounceable: false)

        assertError(
            .senderKeyMismatch,
            request: makeRequest(senderAddress: otherAddress)
        )
    }

    func testRejectsMalformedNoncanonicalAndTestnetSenders() throws {
        let senderAddress = try TonSwift.Address.parse(Self.sender)
        let testnetSender = senderAddress.toString(
            urlSafe: true,
            testOnly: true,
            bounceable: false
        )
        let uppercaseRawSender = senderAddress.toRaw().uppercased()
        let invalidSenders = [
            "",
            " \(Self.sender)",
            "\(Self.sender) ",
            "not-an-address",
            String(Self.sender.dropLast()) + "A",
            uppercaseRawSender
        ]

        invalidSenders.forEach { sender in
            assertError(
                .invalidSenderAddress,
                request: makeRequest(senderAddress: sender)
            )
        }
        assertError(
            .testnetAddressNotAllowed,
            request: makeRequest(senderAddress: testnetSender)
        )
    }

    func testRejectsMalformedNoncanonicalTestnetAndUnsupportedRecipients() throws {
        let recipientAddress = try TonSwift.Address.parse(Self.recipient)
        let testnetRecipient = recipientAddress.toString(
            urlSafe: true,
            testOnly: true,
            bounceable: true
        )
        let unsupported = TonSwift.Address(
            workchain: 1,
            hash: Data(repeating: 0xA5, count: 32)
        ).toString(urlSafe: true, testOnly: false, bounceable: true)
        let invalidRecipients = [
            "",
            " \(Self.recipient)",
            "\(Self.recipient) ",
            "0:abcd",
            "not-an-address",
            String(Self.recipient.dropLast()) + "A",
            recipientAddress.toRaw().uppercased()
        ]

        invalidRecipients.forEach { recipient in
            assertError(
                .invalidRecipientAddress,
                request: makeRequest(recipientAddress: recipient)
            )
        }
        assertError(
            .testnetAddressNotAllowed,
            request: makeRequest(recipientAddress: testnetRecipient)
        )
        assertError(
            .unsupportedWorkchain,
            request: makeRequest(recipientAddress: unsupported)
        )
    }

    func testRejectsOversizedTextInputsAtCheapClassifierBounds() {
        assertError(
            .invalidSenderAddress,
            request: makeRequest(senderAddress: String(repeating: "A", count: 1_048_576))
        )
        assertError(
            .invalidRecipientAddress,
            request: makeRequest(
                recipientAddress: String(
                    repeating: "A",
                    count: TonTransferTransactionBuilder.maximumAddressInputBytes + 1
                )
            )
        )
        assertError(
            .invalidAmount,
            request: makeRequest(
                amountNanotons: String(
                    repeating: "9",
                    count: TonTransferTransactionBuilder.maximumAmountDigits + 1
                )
            )
        )
        assertError(
            .invalidComment,
            request: makeRequest(
                comment: String(
                    repeating: "x",
                    count: TonTransferTransactionBuilder.maximumCommentBytes + 1
                )
            )
        )
    }

    func testRejectsSelfTransferAndFriendlyAddressBounceMismatch() {
        assertError(
            .senderEqualsRecipient,
            request: makeRequest(recipientAddress: Self.sender, bounce: false)
        )
        assertError(
            .bounceFlagMismatch,
            request: makeRequest(bounce: false)
        )
    }

    func testRejectsNoncanonicalZeroFractionalUnicodeAndOversizedAmounts() {
        let invalidAmounts = [
            "",
            "0",
            "00",
            "01",
            "+1",
            "-1",
            "1.0",
            " 1",
            "1 ",
            "١",
            "1329227995784915872903807060280344576"
        ]

        invalidAmounts.forEach { amount in
            assertError(
                .invalidAmount,
                request: makeRequest(amountNanotons: amount)
            )
        }
    }

    func testAcceptsLargestRepresentableCoinsValue() throws {
        let maximum = "1329227995784915872903807060280344575"
        let result = try build(request: makeRequest(amountNanotons: maximum))

        XCTAssertFalse(result.boc.isEmpty)
    }

    func testRejectsSequenceNumberThatDoesNotFitWalletV4Contract() {
        assertError(
            .invalidSequenceNumber,
            request: makeRequest(sequenceNumber: UInt64(UInt32.max) + 1)
        )
        assertError(
            .invalidStateInitPolicy,
            request: makeRequest(sequenceNumber: 1, includeStateInit: true)
        )
    }

    func testRejectsExpiredShortLivedLongLivedAndOverflowingExpirations() {
        let invalidExpirations = [
            Self.now - 1,
            Self.now,
            Self.now + TonTransferTransactionBuilder.minimumLifetimeSeconds - 1,
            Self.now + TonTransferTransactionBuilder.maximumLifetimeSeconds + 1,
            UInt64(UInt32.max) + 1
        ]

        invalidExpirations.forEach { validUntil in
            assertError(
                .invalidExpiration,
                request: makeRequest(validUntil: validUntil)
            )
        }

        assertError(
            .invalidExpiration,
            request: makeRequest(),
            now: UInt64(UInt32.max) + 1
        )
    }

    func testRejectsEmptyOversizedNoncanonicalAndControlCharacterComments() {
        let invalidComments = [
            "",
            "   ",
            "line\nbreak",
            "null\0byte",
            "right\u{202E}left",
            "zero\u{200B}width",
            "e" + String(UnicodeScalar(0x301)!),
            "arabic" + String(UnicodeScalar(0x061C)!),
            "mongolian" + String(UnicodeScalar(0x180E)!),
            "private" + String(UnicodeScalar(0xE000)!),
            "tag" + String(UnicodeScalar(0xE0001)!),
            "noncharacter" + String(UnicodeScalar(0xFDD0)!),
            String(repeating: "a", count: TonTransferTransactionBuilder.maximumCommentBytes + 1)
        ]

        invalidComments.forEach { comment in
            assertError(
                .invalidComment,
                request: makeRequest(comment: comment)
            )
        }
    }

    func testAcceptsBoundedCanonicalUnicodeComment() throws {
        let result = try build(request: makeRequest(comment: "Fearless TON 🚀"))

        XCTAssertFalse(result.boc.isEmpty)
    }

    func testCriticalFieldsAreCryptographicallyBoundIntoMessageHash() throws {
        let baseline = try build()
        let variants = try [
            build(request: makeRequest(amountNanotons: "100000001")),
            build(request: makeRequest(sequenceNumber: 63)),
            build(request: makeRequest(validUntil: Self.validUntil + 1)),
            build(request: makeRequest(comment: "different")),
            build(request: makeRequest(recipientAddress: try alternateRecipient()))
        ]

        variants.forEach { variant in
            XCTAssertNotEqual(variant.messageHashHex, baseline.messageHashHex)
            XCTAssertNotEqual(variant.boc, baseline.boc)
        }
        XCTAssertEqual(Set(variants.map(\.messageHashHex)).count, variants.count)
    }

    func testOutputIsDeterministicBoundedAndRoundTripsThroughTonBocParser() throws {
        let first = try build()
        let second = try build()
        let roots = try Cell.fromBoc(src: first.boc)

        XCTAssertEqual(first, second)
        XCTAssertLessThan(first.boc.count, 16 * 1024)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].hash().hexString, first.messageHashHex)
    }

    private func build(
        request: TonTransferTransactionRequest? = nil,
        privateKey: Data = TonTransferTransactionBuilderTests.privateKey,
        now: UInt64 = TonTransferTransactionBuilderTests.now
    ) throws -> TonSignedExternalMessage {
        try TonTransferTransactionBuilder.buildAndSign(
            request: request ?? makeRequest(),
            privateKeySeed: privateKey,
            now: now
        )
    }

    private func makeRequest(
        asset: TonTransferAsset = .nativeTon,
        network: TonTransferNetwork = .mainnet,
        senderAddress: String = TonTransferTransactionBuilderTests.sender,
        recipientAddress: String = TonTransferTransactionBuilderTests.recipient,
        amountNanotons: String = "100000000",
        sequenceNumber: UInt64 = 62,
        includeStateInit: Bool? = nil,
        validUntil: UInt64 = TonTransferTransactionBuilderTests.validUntil,
        bounce: Bool = true,
        comment: String? = "Fearless TON"
    ) -> TonTransferTransactionRequest {
        TonTransferTransactionRequest(
            asset: asset,
            network: network,
            senderAddress: senderAddress,
            recipientAddress: recipientAddress,
            amountNanotons: amountNanotons,
            sequenceNumber: sequenceNumber,
            includeStateInit: includeStateInit,
            validUntil: validUntil,
            bounce: bounce,
            comment: comment
        )
    }

    private func alternateRecipient() throws -> String {
        let key = try Curve25519.Signing.PrivateKey(
            rawRepresentation: Data(repeating: 0x42, count: 32)
        )
        return try WalletV4R2(
            workchain: 0,
            publicKey: key.publicKey.rawRepresentation
        ).address().toString(urlSafe: true, testOnly: false, bounceable: true)
    }

    private func assertError(
        _ expected: TonTransferTransactionBuilderError,
        request: TonTransferTransactionRequest? = nil,
        privateKey: Data = TonTransferTransactionBuilderTests.privateKey,
        now: UInt64 = TonTransferTransactionBuilderTests.now,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try build(request: request, privateKey: privateKey, now: now),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(
                error as? TonTransferTransactionBuilderError,
                expected,
                file: file,
                line: line
            )
        }
    }
}

#if DEBUG
final class TonSendServiceTests: XCTestCase {
    private static let now: UInt64 = 1_700_000_000
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let account = try! TonKeyDerivation.deriveAccount(mnemonic: mnemonic)
    private static let sender = account.addressNonBounceable
    private static let recipient = "EQAimhPwOYc5Z1JP_pddxo82SHOl67T0Lklw91pKtSX2Q094"
    private static let mismatchedSender = "UQDnBF4JTFKHTYjulEJyNd4dstLGH1m51UrLdu01_tw4zz3r"

    func testNativeMainnetSendEmulatesAndBroadcastsTheExactSignedBoc() async throws {
        let remote = FakeRemote()
        remote.walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        remote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 12_345)

        let result = try await makeService(remote: remote).sendUnquotedForTesting(makeRequest())

        XCTAssertEqual(remote.callOrder, ["walletState", "emulate", "broadcast"])
        XCTAssertEqual(remote.walletAddresses, [Self.sender])
        XCTAssertEqual(remote.emulatedBocs, [result.prepared.signedMessage.bocBase64])
        XCTAssertEqual(remote.broadcastBocs, remote.emulatedBocs)
        XCTAssertEqual(result.prepared.emulation.totalFeeNanotons, 12_345)
        XCTAssertEqual(result.prepared.signedMessage.sequenceNumber, 7)
        XCTAssertEqual(result.prepared.signedMessage.validUntil, Self.now + 120)
        XCTAssertFalse(result.prepared.signedMessage.includesStateInit)

        let broadcast = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(remote.broadcastBocs.first)))
        let roots = try Cell.fromBoc(src: broadcast)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].hash().hexString, result.messageHashHex)
    }

    func testEstimateReturnsPositiveEmulatedFeeWithoutBroadcast() async throws {
        let remote = FakeRemote()
        remote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 777)

        let result = try await makeService(remote: remote).estimate(makeEstimateRequest())

        XCTAssertEqual(result.emulation.totalFeeNanotons, 777)
        XCTAssertEqual(remote.callOrder, ["walletState", "emulate"])
        XCTAssertEqual(remote.unsignedEmulationCount, 1)
        XCTAssertEqual(remote.signedEmulationCount, 0)
        XCTAssertTrue(remote.broadcastBocs.isEmpty)
    }

    func testBoundQuoteReproducesExactTemplateAndExactFeeBeforeBroadcast() async throws {
        let remote = FakeRemote()
        remote.walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        remote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 12_345)
        let service = makeService(remote: remote)

        let quote = try await service.quote(makeEstimateRequest())
        let result = try await service.send(makeRequest(), feeQuote: quote)

        XCTAssertEqual(quote.feeNanotons, 12_345)
        XCTAssertEqual(
            quote.unsignedMessage.signingPayloadHashHex,
            result.prepared.signedMessage.signingPayloadHashHex
        )
        XCTAssertNotEqual(quote.unsignedMessage.boc, result.prepared.signedMessage.boc)
        XCTAssertEqual(result.prepared.emulation.totalFeeNanotons, quote.feeNanotons)
        XCTAssertEqual(remote.unsignedEmulationCount, 1)
        XCTAssertEqual(remote.signedEmulationCount, 1)
        XCTAssertEqual(remote.broadcastBocs, [result.prepared.signedMessage.bocBase64])
        XCTAssertEqual(
            remote.callOrder,
            ["walletState", "emulate", "walletState", "emulate", "broadcast"]
        )
    }

    func testFreshSendRequiresQuoteBeforeMnemonicDerivationOrRemoteWork() async {
        let remote = FakeRemote()
        let service = makeService(remote: remote)

        let error: Error?
        do {
            _ = try await service.send(
                makeRequest(mnemonic: "this must never be parsed"),
                feeQuote: nil
            )
            error = nil
        } catch let caught {
            error = caught
        }

        XCTAssertEqual(error as? TonSendServiceError, .feeQuoteRequired)
        XCTAssertTrue(remote.callOrder.isEmpty)
        XCTAssertTrue(remote.recipientInspectionAddresses.isEmpty)
        XCTAssertTrue(remote.emulatedBocs.isEmpty)
        XCTAssertTrue(remote.broadcastBocs.isEmpty)
    }

    func testQuoteMutationExpiryWalletDriftAndFeeDriftAllFailClosed() async throws {
        let quoteRemote = FakeRemote()
        quoteRemote.walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        quoteRemote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 100)
        let quote = try await makeService(remote: quoteRemote).quote(makeEstimateRequest())

        let mismatchedRemote = FakeRemote()
        let mismatch = await sendError(
            quotedService: makeService(remote: mismatchedRemote),
            request: makeRequest(amountNanotons: "100000001"),
            quote: quote
        )
        XCTAssertEqual(mismatch as? TonSendServiceError, .feeQuoteMismatch)
        XCTAssertTrue(mismatchedRemote.callOrder.isEmpty)

        let clock = LockedClock(Self.now + TonTransferFeeQuote.maximumAgeSeconds + 1)
        let expiredRemote = FakeRemote()
        let expiredService = TonSendService(
            remote: expiredRemote,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { clock.value }
        )
        let expired = await sendError(
            quotedService: expiredService,
            request: makeRequest(),
            quote: quote
        )
        XCTAssertEqual(expired as? TonSendServiceError, .feeQuoteExpired)
        XCTAssertTrue(expiredRemote.callOrder.isEmpty)

        let driftRemote = FakeRemote()
        driftRemote.walletState = TonWalletRemoteState(sequenceNumber: 8, isInitialized: true)
        let stateDrift = await sendError(
            quotedService: makeService(remote: driftRemote),
            request: makeRequest(),
            quote: quote
        )
        XCTAssertEqual(stateDrift as? TonSendServiceError, .walletStateChangedSinceQuote)
        XCTAssertEqual(driftRemote.callOrder, ["walletState"])
        XCTAssertEqual(driftRemote.signedEmulationCount, 0)
        XCTAssertTrue(driftRemote.broadcastBocs.isEmpty)

        let feeDriftRemote = FakeRemote()
        feeDriftRemote.walletState = quote.walletState
        feeDriftRemote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 101)
        let feeDrift = await sendError(
            quotedService: makeService(remote: feeDriftRemote),
            request: makeRequest(),
            quote: quote
        )
        assertUnknownOutcome(feeDrift)
        XCTAssertEqual(feeDriftRemote.signedEmulationCount, 1)
        XCTAssertTrue(feeDriftRemote.broadcastBocs.isEmpty)
        XCTAssertEqual(feeDriftRemote.reconciledBocs.count, 3)
    }

    func testProcessRestartLoadsJournalAndReconcilesBeforeAnyRebroadcast() async throws {
        let quoteRemote = FakeRemote()
        quoteRemote.walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        quoteRemote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 100)
        let quote = try await makeService(remote: quoteRemote).quote(makeEstimateRequest())

        let journal = TonInMemoryPendingIntentJournal()
        let firstRemote = FakeRemote()
        firstRemote.walletState = quote.walletState
        firstRemote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: quote.feeNanotons)
        firstRemote.reconciliation = .notFound
        let firstService = TonSendService(
            remote: firstRemote,
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { Self.now }
        )
        let firstError = await sendError(
            quotedService: firstService,
            request: makeRequest(),
            quote: quote
        )
        let firstHash = try XCTUnwrap(unknownOutcomeHash(firstError))
        XCTAssertEqual(firstRemote.broadcastBocs.count, 1)
        XCTAssertNotNil(try journal.load(senderRaw: quote.identity.sender))

        let blockedRemote = FakeRemote()
        blockedRemote.reconciliation = .notFound
        let blockedError = await sendError(
            quotedService: TonSendService(
                remote: blockedRemote,
                pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
                clock: { Self.now }
            ),
            request: makeRequest(amountNanotons: "100000001"),
            quote: nil
        )
        XCTAssertEqual(unknownOutcomeHash(blockedError), firstHash)
        XCTAssertEqual(blockedRemote.reconciledBocs.count, 3)
        XCTAssertTrue(blockedRemote.callOrder.isEmpty)
        XCTAssertTrue(blockedRemote.broadcastBocs.isEmpty)
        XCTAssertNotNil(try journal.load(senderRaw: quote.identity.sender))

        let recoveryRemote = FakeRemote()
        recoveryRemote.reconciliation = .confirmed
        let recoveryService = TonSendService(
            remote: recoveryRemote,
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { Self.now }
        )
        let recovered = try await recoveryService.send(makeRequest(), feeQuote: nil)

        XCTAssertEqual(recovered.messageHashHex, firstHash)
        XCTAssertEqual(recoveryRemote.reconciledBocs.count, 1)
        XCTAssertTrue(recoveryRemote.callOrder.isEmpty)
        XCTAssertTrue(recoveryRemote.emulatedBocs.isEmpty)
        XCTAssertTrue(recoveryRemote.broadcastBocs.isEmpty)
        let tombstone = try XCTUnwrap(journal.load(senderRaw: quote.identity.sender))
        XCTAssertTrue(tombstone.confirmed)
        XCTAssertEqual(tombstone.message.messageHashHex, firstHash)

        // A process restart before the UI acknowledges success must surface the same receipt
        // without signing, emulating, or broadcasting another transfer.
        let restartedRemote = FakeRemote()
        let restarted = try await TonSendService(
            remote: restartedRemote,
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { Self.now }
        ).send(makeRequest(), feeQuote: nil)
        XCTAssertEqual(restarted.messageHashHex, firstHash)
        XCTAssertTrue(restartedRemote.reconciledBocs.isEmpty)
        XCTAssertTrue(restartedRemote.callOrder.isEmpty)

        let differentRemote = FakeRemote()
        let differentError = await sendError(
            quotedService: TonSendService(
                remote: differentRemote,
                pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
                clock: { Self.now }
            ),
            request: makeRequest(amountNanotons: "100000001"),
            quote: nil
        )
        guard let serviceError = differentError as? TonSendServiceError,
              case let .priorIntentConfirmed(identity, messageHashHex) = serviceError
        else {
            return XCTFail("A confirmed prior intent was reported as the new transfer's success")
        }
        XCTAssertEqual(identity, quote.identity)
        XCTAssertEqual(messageHashHex, firstHash)
        XCTAssertTrue(differentRemote.reconciledBocs.isEmpty)
        XCTAssertTrue(differentRemote.callOrder.isEmpty)

        var stalePending = tombstone
        stalePending.confirmed = false
        XCTAssertThrowsError(try journal.save(stalePending)) { error in
            XCTAssertEqual(error as? TonPendingIntentJournalError, .conflict)
        }
        let staleCoordinator = TonPendingIntentCoordinator(journal: journal)
        guard case .retry = try await staleCoordinator.begin(quote.identity) else {
            return XCTFail("Expected the confirmed tombstone to load for recovery")
        }
        try await staleCoordinator.retainPending(stalePending)
        XCTAssertTrue(try XCTUnwrap(journal.load(senderRaw: quote.identity.sender)).confirmed)

        let friendlySender = try TonSwift.Address.parse(raw: quote.identity.sender)
            .toFriendly()
            .toString()
        try await recoveryService.acknowledgeConfirmedTransfer(
            senderAddress: friendlySender,
            identity: quote.identity,
            messageHashHex: firstHash
        )
        XCTAssertNil(try journal.load(senderRaw: quote.identity.sender))
    }

    func testFreshDisplayedQuoteNeverRebroadcastsOlderPendingBoc() async throws {
        let quoteRemoteA = FakeRemote()
        quoteRemoteA.walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        quoteRemoteA.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 100)
        let quoteA = try await makeService(remote: quoteRemoteA).quote(makeEstimateRequest())

        let journal = TonInMemoryPendingIntentJournal()
        let firstRemote = FakeRemote()
        firstRemote.walletState = quoteA.walletState
        firstRemote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 100)
        firstRemote.reconciliation = .notFound
        let firstService = TonSendService(
            remote: firstRemote,
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { Self.now }
        )
        let firstError = await sendError(
            quotedService: firstService,
            request: makeRequest(),
            quote: quoteA
        )
        let oldHash = try XCTUnwrap(unknownOutcomeHash(firstError))

        let quoteRemoteB = FakeRemote()
        quoteRemoteB.walletState = quoteA.walletState
        quoteRemoteB.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 101)
        let quoteB = try await makeService(remote: quoteRemoteB).quote(makeEstimateRequest())
        XCTAssertNotEqual(quoteA.quoteIDHex, quoteB.quoteIDHex)

        let recoveryRemote = FakeRemote()
        recoveryRemote.reconciliation = .notFound
        let recoveryService = TonSendService(
            remote: recoveryRemote,
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { Self.now }
        )
        let error = await sendError(
            quotedService: recoveryService,
            request: makeRequest(),
            quote: quoteB
        )

        XCTAssertEqual(unknownOutcomeHash(error), oldHash)
        XCTAssertEqual(recoveryRemote.reconciledBocs.count, 3)
        XCTAssertTrue(recoveryRemote.emulatedBocs.isEmpty)
        XCTAssertTrue(recoveryRemote.broadcastBocs.isEmpty)
    }

    func testPersistedRecoveryRequiresStoredCredentialedEndpointBeforeRemoteWork() async throws {
        let quoteRemote = FakeRemote()
        quoteRemote.walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        let quote = try await makeService(remote: quoteRemote).quote(makeEstimateRequest())
        let journal = TonInMemoryPendingIntentJournal()
        let firstRemote = FakeRemote()
        firstRemote.walletState = quote.walletState
        firstRemote.reconciliation = .notFound
        let firstError = await sendError(
            quotedService: TonSendService(
                remote: firstRemote,
                pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
                clock: { Self.now }
            ),
            request: makeRequest(),
            quote: quote
        )
        let oldHash = try XCTUnwrap(unknownOutcomeHash(firstError))

        for untrustedOrigin in [nil, "https://other-reviewed.example"] as [String?] {
            let recoveryRemote = FakeRemote()
            recoveryRemote.reviewedSignedOperationOrigin = untrustedOrigin
            let error = await sendError(
                quotedService: TonSendService(
                    remote: recoveryRemote,
                    pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
                    clock: { Self.now }
                ),
                request: makeRequest(),
                quote: nil
            )
            XCTAssertEqual(unknownOutcomeHash(error), oldHash)
            XCTAssertTrue(recoveryRemote.reconciledBocs.isEmpty)
            XCTAssertTrue(recoveryRemote.emulatedBocs.isEmpty)
            XCTAssertTrue(recoveryRemote.broadcastBocs.isEmpty)
        }
    }

    func testPersistedRecoveryRunsBeforeSigningCredentialsAreRequested() async throws {
        let quoteRemote = FakeRemote()
        quoteRemote.walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        let quote = try await makeService(remote: quoteRemote).quote(makeEstimateRequest())
        let journal = TonInMemoryPendingIntentJournal()
        let firstRemote = FakeRemote()
        firstRemote.walletState = quote.walletState
        firstRemote.reconciliation = .notFound
        let firstError = await sendError(
            quotedService: TonSendService(
                remote: firstRemote,
                pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
                clock: { Self.now }
            ),
            request: makeRequest(),
            quote: quote
        )
        let oldHash = try XCTUnwrap(unknownOutcomeHash(firstError))

        let recoveryRemote = FakeRemote()
        recoveryRemote.reconciliation = .confirmed
        let recovered = try await TonSendService(
            remote: recoveryRemote,
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { Self.now }
        ).send(
            makeEstimateRequest(),
            feeQuote: nil,
            signingCredentials: {
                XCTFail("Persisted recovery requested signing credentials")
                throw TonSendServiceError.invalidAccount
            }
        )

        XCTAssertEqual(recovered.messageHashHex, oldHash)
        XCTAssertEqual(recoveryRemote.reconciledBocs.count, 1)
        XCTAssertTrue(recoveryRemote.emulatedBocs.isEmpty)
        XCTAssertTrue(recoveryRemote.broadcastBocs.isEmpty)
    }

    func testJournalWriteFailurePreventsEverySignedRemoteExposure() async {
        let remote = FakeRemote()
        remote.walletState = TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
        let service = TonSendService(
            remote: remote,
            pendingCoordinator: TonPendingIntentCoordinator(journal: FailOnSaveJournal()),
            clock: { Self.now }
        )

        let error = await sendError(service: service, request: makeRequest())

        XCTAssertEqual(error as? TonPendingIntentJournalError, .unavailable)
        XCTAssertEqual(remote.callOrder, ["walletState"])
        XCTAssertEqual(remote.signedEmulationCount, 0)
        XCTAssertTrue(remote.emulatedBocs.isEmpty)
        XCTAssertTrue(remote.broadcastBocs.isEmpty)
        XCTAssertTrue(remote.reconciledBocs.isEmpty)
    }

    func testMemoRequiredRecipientStopsBeforeWalletStateOrBearerMessageExposure() async {
        let remote = FakeRemote()
        remote.memoRequired = true

        let error = await sendError(service: makeService(remote: remote), request: makeRequest())

        XCTAssertEqual(error as? TonSendServiceError, .recipientMemoRequired)
        XCTAssertEqual(remote.recipientInspectionAddresses, [Self.recipient])
        XCTAssertTrue(remote.callOrder.isEmpty)
        XCTAssertTrue(remote.emulatedBocs.isEmpty)
        XCTAssertTrue(remote.broadcastBocs.isEmpty)
    }

    func testUnsupportedJettonAndTestnetFailBeforeAnyRemoteCall() async {
        let jettonRemote = FakeRemote()
        let jettonError = await sendError(
            service: makeService(remote: jettonRemote),
            request: makeRequest(asset: .jetton(masterAddress: "malformed-master"))
        )
        XCTAssertEqual(jettonError as? TonTransferTransactionBuilderError, .unsupportedAsset)
        XCTAssertTrue(jettonRemote.callOrder.isEmpty)

        let testnetRemote = FakeRemote()
        let testnetError = await sendError(
            service: makeService(remote: testnetRemote),
            request: makeRequest(network: .testnet)
        )
        XCTAssertEqual(testnetError as? TonTransferTransactionBuilderError, .unsupportedNetwork)
        XCTAssertTrue(testnetRemote.callOrder.isEmpty)
    }

    func testInvalidMnemonicAndSenderBindingFailBeforeAnyRemoteCall() async {
        let mnemonicRemote = FakeRemote()
        let mnemonicError = await sendError(
            service: makeService(remote: mnemonicRemote),
            request: makeRequest(mnemonic: "not a valid mnemonic")
        )
        XCTAssertEqual(mnemonicError as? TonSendServiceError, .invalidAccount)
        XCTAssertTrue(mnemonicRemote.callOrder.isEmpty)

        let mismatchRemote = FakeRemote()
        let mismatchError = await sendError(
            service: makeService(remote: mismatchRemote),
            request: makeRequest(senderAddress: Self.mismatchedSender)
        )
        XCTAssertEqual(mismatchError as? TonTransferTransactionBuilderError, .senderKeyMismatch)
        XCTAssertTrue(mismatchRemote.callOrder.isEmpty)
    }

    func testMalformedRecipientAmountBounceAndCommentFailBeforeAnyRemoteCall() async {
        let cases: [(TonNativeSendRequest, TonTransferTransactionBuilderError)] = [
            (makeRequest(senderAddress: String(repeating: "A", count: 1_048_576)), .invalidSenderAddress),
            (
                makeRequest(
                    recipientAddress: String(
                        repeating: "A",
                        count: TonTransferTransactionBuilder.maximumAddressInputBytes + 1
                    )
                ),
                .invalidRecipientAddress
            ),
            (makeRequest(recipientAddress: "../recipient"), .invalidRecipientAddress),
            (makeRequest(amountNanotons: "0"), .invalidAmount),
            (makeRequest(amountNanotons: "01"), .invalidAmount),
            (makeRequest(amountNanotons: "9223372036854775808"), .invalidAmount),
            (makeRequest(amountNanotons: String(repeating: "9", count: 20)), .invalidAmount),
            (makeRequest(amountNanotons: String(repeating: "9", count: 1_048_576)), .invalidAmount),
            (makeRequest(bounce: false), .bounceFlagMismatch),
            (makeRequest(comment: "line\nbreak"), .invalidComment),
            (makeRequest(comment: String(repeating: "x", count: 257)), .invalidComment),
            (makeRequest(comment: String(repeating: "x", count: 1_048_576)), .invalidComment)
        ]

        for (request, expected) in cases {
            let remote = FakeRemote()
            let error = await sendError(service: makeService(remote: remote), request: request)
            XCTAssertEqual(error as? TonTransferTransactionBuilderError, expected)
            XCTAssertTrue(remote.callOrder.isEmpty, "Unexpected remote calls for \(expected)")
        }
    }

    func testOversizedSequenceFailsAfterStateButBeforeEmulationOrBroadcast() async {
        let remote = FakeRemote()
        remote.walletState = TonWalletRemoteState(
            sequenceNumber: UInt64(UInt32.max) + 1,
            isInitialized: true
        )

        let error = await sendError(service: makeService(remote: remote), request: makeRequest())

        XCTAssertEqual(error as? TonTransferTransactionBuilderError, .invalidSequenceNumber)
        XCTAssertEqual(remote.callOrder, ["walletState"])
    }

    func testUninitializedNonzeroSequenceFailsBeforeEmulationAndBroadcast() async {
        let remote = FakeRemote()
        remote.walletState = TonWalletRemoteState(sequenceNumber: 1, isInitialized: false)

        let error = await sendError(service: makeService(remote: remote), request: makeRequest())

        XCTAssertEqual(error as? TonSendServiceError, .inconsistentWalletState)
        XCTAssertEqual(remote.callOrder, ["walletState"])
    }

    func testUninitializedSequenceZeroIncludesStateInit() async throws {
        let remote = FakeRemote()
        remote.walletState = TonWalletRemoteState(sequenceNumber: 0, isInitialized: false)

        let result = try await makeService(remote: remote).estimate(makeEstimateRequest())

        XCTAssertTrue(result.emulationMessage.includesStateInit)
        XCTAssertEqual(remote.callOrder, ["walletState", "emulate"])
    }

    func testVerifiedInitializedSequenceZeroOmitsStateInit() async throws {
        let remote = FakeRemote()
        remote.walletState = TonWalletRemoteState(sequenceNumber: 0, isInitialized: true)

        let result = try await makeService(remote: remote).estimate(makeEstimateRequest())

        XCTAssertFalse(result.emulationMessage.includesStateInit)
        XCTAssertEqual(remote.callOrder, ["walletState", "emulate"])
    }

    func testRejectedEmulationNeverBroadcasts() async {
        let remote = FakeRemote()
        remote.emulation = TonEmulationResult(accepted: false, totalFeeNanotons: 10)

        let error = await sendError(service: makeService(remote: remote), request: makeRequest())

        assertUnknownOutcome(error)
        XCTAssertEqual(remote.callOrder, ["walletState", "emulate"])
        XCTAssertTrue(remote.broadcastBocs.isEmpty)
    }

    func testMissingZeroAndExcessiveEmulationFeesNeverBroadcast() async {
        let invalidFees: [UInt64?] = [
            nil,
            0,
            TonSendService.defaultMaximumFeeNanotons + 1,
            UInt64.max
        ]

        for fee in invalidFees {
            let remote = FakeRemote()
            remote.emulation = TonEmulationResult(accepted: true, totalFeeNanotons: fee)

            let error = await sendError(service: makeService(remote: remote), request: makeRequest())

            assertUnknownOutcome(error)
            XCTAssertEqual(remote.callOrder, ["walletState", "emulate"])
            XCTAssertTrue(remote.broadcastBocs.isEmpty)
        }
    }

    func testRemoteErrorsStopThePipelineAtTheFailingStage() async {
        let stateRemote = FakeRemote()
        stateRemote.failureStage = .walletState
        let stateError = await sendError(service: makeService(remote: stateRemote), request: makeRequest())
        XCTAssertNotNil(stateError)
        XCTAssertEqual(stateRemote.callOrder, ["walletState"])

        let emulationRemote = FakeRemote()
        emulationRemote.failureStage = .emulate
        let emulationError = await sendError(
            service: makeService(remote: emulationRemote),
            request: makeRequest()
        )
        XCTAssertNotNil(emulationError)
        assertUnknownOutcome(emulationError)
        XCTAssertEqual(emulationRemote.callOrder, ["walletState", "emulate"])

        let broadcastRemote = FakeRemote()
        broadcastRemote.failureStage = .broadcast
        let broadcastError = await sendError(
            service: makeService(remote: broadcastRemote),
            request: makeRequest()
        )
        XCTAssertNotNil(broadcastError)
        assertUnknownOutcome(broadcastError)
        XCTAssertEqual(broadcastRemote.callOrder, ["walletState", "emulate", "broadcast"])
    }

    func testEveryRemoteStageHasAnExplicitBoundedTimeout() async {
        let expectations: [(FakeRemote.Stage, [String])] = [
            (.recipientInspection, []),
            (.walletState, ["walletState"]),
            (.emulate, ["walletState", "emulate"]),
            (.broadcast, ["walletState", "emulate", "broadcast"]),
            (.reconcile, ["walletState", "emulate", "broadcast"])
        ]

        for (stage, order) in expectations {
            let remote = FakeRemote()
            remote.suspendedStage = stage
            let service = TonSendService(
                remote: remote,
                remoteTimeoutNanoseconds: 10_000_000,
                pendingCoordinator: TonPendingIntentCoordinator(),
                clock: { Self.now }
            )

            let error = await sendError(service: service, request: makeRequest())

            if stage == .recipientInspection {
                XCTAssertEqual(error as? TonSendServiceError, .recipientInspectionTimedOut)
            } else if stage == .walletState {
                XCTAssertEqual(error as? TonSendServiceError, .walletStateTimedOut)
            } else {
                assertUnknownOutcome(error)
            }
            XCTAssertEqual(remote.callOrder, order)
        }
    }

    func testTimeoutReturnsEvenWhenRemoteIgnoresCancellationForever() async {
        let remote = FakeRemote()
        remote.nonResumingStage = .walletState
        let service = TonSendService(
            remote: remote,
            remoteTimeoutNanoseconds: 10_000_000,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { Self.now }
        )
        let startedAt = Date()

        let error = await sendError(service: service, request: makeRequest())

        XCTAssertEqual(error as? TonSendServiceError, .walletStateTimedOut)
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 1)
        XCTAssertEqual(remote.callOrder, ["walletState"])
    }

    func testAlreadyCancelledCallerStartsNoRemoteWork() async {
        let remote = FakeRemote()
        let service = makeService(remote: remote)
        let request = makeRequest()
        let task = Task { () -> Error? in
            withUnsafeCurrentTask { current in
                current?.cancel()
            }
            do {
                _ = try await service.sendUnquotedForTesting(request)
                return nil
            } catch {
                return error
            }
        }

        let error = await task.value

        XCTAssertTrue(error is CancellationError)
        XCTAssertTrue(remote.callOrder.isEmpty)
    }

    func testCallerCancellationDuringEmulationPreventsBroadcast() async {
        let remote = FakeRemote()
        remote.suspendedStage = .emulate
        let emulationStarted = expectation(description: "emulation started")
        remote.emulateStarted = { emulationStarted.fulfill() }
        let service = makeService(remote: remote)
        let request = makeRequest()
        let task = Task {
            try await service.sendUnquotedForTesting(request)
        }

        await fulfillment(of: [emulationStarted], timeout: 1)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to stop TON send")
        } catch {
            assertUnknownOutcome(error)
        }
        XCTAssertEqual(remote.callOrder, ["walletState", "emulate"])
        XCTAssertTrue(remote.broadcastBocs.isEmpty)
    }

    func testConcurrentSameSenderSubmitIsSerializedAcrossServiceInstances() async throws {
        let remote = FakeRemote()
        remote.suspendedStage = .walletState
        let stateStarted = expectation(description: "wallet state started")
        remote.walletStateStarted = { stateStarted.fulfill() }
        let coordinator = TonPendingIntentCoordinator()
        let firstService = TonSendService(
            remote: remote,
            pendingCoordinator: coordinator,
            clock: { Self.now }
        )
        let secondService = TonSendService(
            remote: remote,
            pendingCoordinator: coordinator,
            clock: { Self.now }
        )
        let request = makeRequest()
        let firstTask = Task { try await firstService.sendUnquotedForTesting(request) }

        await fulfillment(of: [stateStarted], timeout: 1)
        let secondError = await sendError(service: secondService, request: request)
        XCTAssertEqual(
            secondError as? TonSendServiceError,
            .sendAlreadyInFlight(
                senderAddress: try TonSwift.Address.parse(Self.sender).toRaw()
            )
        )
        XCTAssertEqual(remote.callOrder, ["walletState"])

        firstTask.cancel()
        do {
            _ = try await firstTask.value
            XCTFail("Expected the first request to cancel")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected first request error: \(error)")
        }
        XCTAssertTrue(remote.broadcastBocs.isEmpty)
    }

    func testUnquotedPendingNeverRetriesWithoutStoredEndpointBinding() async {
        let remote = FakeRemote()
        remote.reconciliation = .notFound
        let service = makeService(remote: remote)
        let request = makeRequest()

        let firstError = await sendError(service: service, request: request)
        let firstHash = unknownOutcomeHash(firstError)
        XCTAssertEqual(remote.broadcastBocs.count, 1)

        let secondError = await sendError(service: service, request: request)
        XCTAssertEqual(unknownOutcomeHash(secondError), firstHash)
        XCTAssertEqual(remote.broadcastBocs.count, 1)
        XCTAssertEqual(Set(remote.broadcastBocs).count, 1)
        XCTAssertEqual(remote.signedEmulationCount, 1)
        XCTAssertEqual(remote.callOrder, ["walletState", "emulate", "broadcast"])
        XCTAssertEqual(remote.reconciledBocs.count, 3)
    }

    func testRetryNeverRebroadcastsAfterReconciliationError() async {
        let remote = FakeRemote()
        remote.reconciliation = .notFound
        let service = makeService(remote: remote)
        let request = makeRequest()
        let firstHash = unknownOutcomeHash(
            await sendError(service: service, request: request)
        )
        XCTAssertEqual(remote.broadcastBocs.count, 1)

        remote.failureStage = .reconcile
        let retryError = await sendError(service: service, request: request)

        XCTAssertEqual(unknownOutcomeHash(retryError), firstHash)
        XCTAssertEqual(remote.broadcastBocs.count, 1)

        // If the first signed emulation exposed a valid bearer BOC but failed before
        // recording an emulation result, a retry-side rejection must retain the same
        // exact-hash unknown outcome rather than downgrade to a generic fee error.
        let reemulationRemote = FakeRemote()
        reemulationRemote.failureStage = .emulate
        let reemulationService = makeService(remote: reemulationRemote)
        let reemulationRequest = makeRequest(comment: "retry-side rejection")
        let exposedHash = unknownOutcomeHash(
            await sendError(service: reemulationService, request: reemulationRequest)
        )
        XCTAssertEqual(reemulationRemote.signedEmulationCount, 1)
        XCTAssertTrue(reemulationRemote.broadcastBocs.isEmpty)

        reemulationRemote.failureStage = nil
        reemulationRemote.emulation = TonEmulationResult(
            accepted: false,
            totalFeeNanotons: 100
        )
        let reemulationError = await sendError(
            service: reemulationService,
            request: reemulationRequest
        )

        XCTAssertEqual(unknownOutcomeHash(reemulationError), exposedHash)
        XCTAssertEqual(reemulationRemote.signedEmulationCount, 1)
        XCTAssertTrue(reemulationRemote.broadcastBocs.isEmpty)
        XCTAssertEqual(Set(reemulationRemote.emulatedBocs).count, 1)
    }

    func testRetryNeverRebroadcastsAfterReconciliationTimeout() async {
        let remote = FakeRemote()
        remote.suspendedStage = .reconcile
        let service = TonSendService(
            remote: remote,
            remoteTimeoutNanoseconds: 10_000_000,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { Self.now }
        )
        let request = makeRequest()
        let firstHash = unknownOutcomeHash(
            await sendError(service: service, request: request)
        )
        XCTAssertEqual(remote.broadcastBocs.count, 1)

        let retryError = await sendError(service: service, request: request)

        XCTAssertEqual(unknownOutcomeHash(retryError), firstHash)
        XCTAssertEqual(remote.broadcastBocs.count, 1)
    }

    func testExpiredPendingMessageIsNeverRebroadcast() async {
        let remote = FakeRemote()
        remote.reconciliation = .notFound
        let clock = LockedClock(Self.now)
        let service = TonSendService(
            remote: remote,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { clock.value }
        )
        let request = makeRequest()
        let firstHash = unknownOutcomeHash(
            await sendError(service: service, request: request)
        )
        XCTAssertEqual(remote.broadcastBocs.count, 1)

        clock.value = Self.now + TonSendService.defaultMessageLifetimeSeconds
        let retryError = await sendError(service: service, request: request)

        XCTAssertEqual(unknownOutcomeHash(retryError), firstHash)
        XCTAssertEqual(remote.broadcastBocs.count, 1)
    }

    func testMessageExpiringDuringEmulationIsNeverBroadcast() async {
        let remote = FakeRemote()
        remote.reconciliation = .notFound
        let clock = LockedClock(Self.now)
        remote.emulateStarted = {
            clock.value = Self.now + TonSendService.defaultMessageLifetimeSeconds
        }
        let service = TonSendService(
            remote: remote,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { clock.value }
        )

        let error = await sendError(service: service, request: makeRequest())

        assertUnknownOutcome(error)
        XCTAssertEqual(remote.callOrder, ["walletState", "emulate"])
        XCTAssertTrue(remote.broadcastBocs.isEmpty)
    }

    func testDifferentIntentCannotReplaceUnknownPendingMessage() async {
        let remote = FakeRemote()
        remote.reconciliation = .notFound
        let service = makeService(remote: remote)
        let firstHash = unknownOutcomeHash(
            await sendError(service: service, request: makeRequest())
        )
        XCTAssertEqual(remote.broadcastBocs.count, 1)

        let error = await sendError(
            service: service,
            request: makeRequest(amountNanotons: "100000001")
        )

        // Even three explicit not-found observations cannot revoke a bearer BOC that was
        // already exposed to the remote. A different intent therefore reconciles first, then
        // surfaces the exact old hash instead of replacing or rebroadcasting the pending item.
        XCTAssertEqual(unknownOutcomeHash(error), firstHash)
        XCTAssertEqual(remote.broadcastBocs.count, 1)
        XCTAssertEqual(remote.reconciledBocs.count, 3)
    }

    func testInvalidClockLifetimeAndTimeoutFailBeforeAnyRemoteCall() async {
        let configurations: [(UInt64, UInt64, UInt64)] = [
            (Self.now, TonTransferTransactionBuilder.minimumLifetimeSeconds - 1, 1),
            (Self.now, TonTransferTransactionBuilder.maximumLifetimeSeconds + 1, 1),
            (UInt64(UInt32.max), 120, 1),
            (Self.now, 120, 0)
        ]

        for (now, lifetime, timeout) in configurations {
            let remote = FakeRemote()
            let service = TonSendService(
                remote: remote,
                messageLifetimeSeconds: lifetime,
                remoteTimeoutNanoseconds: timeout,
                pendingCoordinator: TonPendingIntentCoordinator(),
                clock: { now }
            )

            let error = await sendError(service: service, request: makeRequest())

            XCTAssertEqual(error as? TonSendServiceError, .invalidClock)
            XCTAssertTrue(remote.callOrder.isEmpty)
        }

        let zeroFeeCapRemote = FakeRemote()
        let zeroFeeCapService = TonSendService(
            remote: zeroFeeCapRemote,
            maximumFeeNanotons: 0,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { Self.now }
        )
        let zeroFeeCapError = await sendError(
            service: zeroFeeCapService,
            request: makeRequest()
        )
        XCTAssertEqual(zeroFeeCapError as? TonSendServiceError, .invalidClock)
        XCTAssertTrue(zeroFeeCapRemote.callOrder.isEmpty)
    }

    func testEmulationPolicyRejectsEveryUnsafeOrIncompleteSignal() throws {
        let safeExecution = [
            true, false, false, true, true, true, true, true, true, false,
            true, true, true, true, true, true, true, true, true
        ]

        func acceptsExecution(_ values: [Bool]) -> Bool {
            TonEmulationPolicy.acceptsExecution(
                transactionSucceeded: values[0],
                transactionAborted: values[1],
                transactionDestroyed: values[2],
                transactionTypeIsOrdinary: values[3],
                traceEmulated: values[4],
                traceHasWalletV4R2Interface: values[5],
                traceChildrenAreEmpty: values[6],
                transactionAccountMatches: values[7],
                computePhasePresent: values[8],
                computePhaseSkipped: values[9],
                computePhaseSucceeded: values[10],
                computeExitCodeZero: values[11],
                actionPhasePresent: values[12],
                actionPhaseSucceeded: values[13],
                actionCountIsOne: values[14],
                skippedActionCountIsZero: values[15],
                outMessageCountIsOne: values[16],
                inboundMessageMatches: values[17],
                outboundMessageMatches: values[18]
            )
        }

        XCTAssertTrue(acceptsExecution(safeExecution))
        for unsafeIndex in safeExecution.indices {
            var values = safeExecution
            values[unsafeIndex].toggle()
            XCTAssertFalse(
                acceptsExecution(values),
                "Unsafe execution signal at index \(unsafeIndex) was accepted"
            )
        }

        let safeRisk = [false, false, false, true, false, false]
        func acceptsRisk(_ values: [Bool]) -> Bool {
            TonEmulationPolicy.acceptsRisk(
                eventIsScam: values[0],
                eventInProgress: values[1],
                transfersAllRemainingBalance: values[2],
                tonRiskWithinIntent: values[3],
                hasJettonRisk: values[4],
                hasNFTRisk: values[5]
            )
        }

        XCTAssertTrue(acceptsRisk(safeRisk))
        for unsafeIndex in safeRisk.indices {
            var values = safeRisk
            values[unsafeIndex].toggle()
            XCTAssertFalse(
                acceptsRisk(values),
                "Unsafe risk signal at index \(unsafeIndex) was accepted"
            )
        }

        let maximum = TonSendService.defaultMaximumFeeNanotons
        XCTAssertEqual(try TonEmulationPolicy.feeNanotons(1), 1)
        XCTAssertEqual(try TonEmulationPolicy.feeNanotons(Int64(maximum)), maximum)
        for invalidFee in [
            Int64.min,
            -1,
            0,
            Int64(maximum + 1),
            Int64.max
        ] {
            XCTAssertThrowsError(try TonEmulationPolicy.feeNanotons(invalidFee)) { error in
                XCTAssertEqual(error as? TonTransferRemoteError, .invalidFee)
            }
        }
    }

    func testAccountPolicyAcceptsLiveShapedNilFlagsAndRejectsExplicitDanger() throws {
        XCTAssertTrue(
            try TonAccountSafetyPolicy.walletIsInitialized(
                status: "active",
                isWallet: true,
                isScam: nil,
                isSuspended: nil,
                interfaces: ["wallet_v4r2"]
            )
        )
        for status in ["nonexist", "uninit"] {
            XCTAssertFalse(
                try TonAccountSafetyPolicy.walletIsInitialized(
                    status: status,
                    isWallet: false,
                    isScam: nil,
                    isSuspended: nil,
                    interfaces: nil
                )
            )
            XCTAssertFalse(
                try TonAccountSafetyPolicy.recipientRequiresMemo(
                    status: status,
                    isScam: nil,
                    isSuspended: nil,
                    memoRequired: nil
                )
            )
        }
        XCTAssertFalse(
            try TonAccountSafetyPolicy.recipientRequiresMemo(
                status: "active",
                isScam: nil,
                isSuspended: nil,
                memoRequired: nil
            )
        )
        XCTAssertTrue(
            try TonAccountSafetyPolicy.recipientRequiresMemo(
                status: "active",
                isScam: nil,
                isSuspended: nil,
                memoRequired: true
            )
        )

        let unsafeWallets: [(Bool?, Bool?)] = [(true, nil), (nil, true)]
        for (isScam, isSuspended) in unsafeWallets {
            XCTAssertThrowsError(
                try TonAccountSafetyPolicy.walletIsInitialized(
                    status: "active",
                    isWallet: true,
                    isScam: isScam,
                    isSuspended: isSuspended,
                    interfaces: ["wallet_v4r2"]
                )
            )
            XCTAssertThrowsError(
                try TonAccountSafetyPolicy.recipientRequiresMemo(
                    status: "nonexist",
                    isScam: isScam,
                    isSuspended: isSuspended,
                    memoRequired: nil
                )
            )
        }
        XCTAssertThrowsError(
            try TonAccountSafetyPolicy.walletIsInitialized(
                status: "active",
                isWallet: false,
                isScam: nil,
                isSuspended: nil,
                interfaces: ["wallet_v4r2"]
            )
        )
        XCTAssertThrowsError(
            try TonAccountSafetyPolicy.walletIsInitialized(
                status: "active",
                isWallet: true,
                isScam: nil,
                isSuspended: nil,
                interfaces: []
            )
        )
        XCTAssertThrowsError(
            try TonAccountSafetyPolicy.recipientRequiresMemo(
                status: "frozen",
                isScam: nil,
                isSuspended: nil,
                memoRequired: nil
            )
        )
    }

    func testTonAPIUnsignedEmulationUsesExactTraceEndpointBodyAndSignatureBypassQuery() async throws {
        let message = try fixtureUnsignedMessage()
        let serverURL = try XCTUnwrap(URL(string: "https://ton-api-fixture.invalid"))
        let transport = TonAPIUnsignedEmulationFixtureTransport(
            responseData: try makeTraceFixtureData(externalMessageBoc: message.boc),
            expectedServerURL: serverURL,
            expectedMessageBocBase64: message.bocBase64
        )
        let remote = TonAPIRemoteClient(
            client: Client(serverURL: serverURL, transport: transport)
        )

        let result = try await remote.emulateUnsigned(
            message: message,
            intent: TonEmulationIntent(request: makeEstimateRequest())
        )

        XCTAssertEqual(
            result,
            TonEmulationResult(accepted: true, totalFeeNanotons: 123_456)
        )
    }

    func testTonAPIBroadcastUsesExactPathAndOneFieldBodyAndRejectsNon2xx() async throws {
        let message = try fixtureSignedMessage()
        let serverURL = try XCTUnwrap(URL(string: "https://ton-api-fixture.invalid"))
        let successRemote = TonAPIRemoteClient(
            trustedTestClient: Client(
                serverURL: serverURL,
                transport: TonAPIBroadcastFixtureTransport(
                    responseStatus: .ok,
                    expectedServerURL: serverURL,
                    expectedMessageBocBase64: message.bocBase64
                )
            )
        )
        try await successRemote.broadcast(message: message)

        let rejectedRemote = TonAPIRemoteClient(
            trustedTestClient: Client(
                serverURL: serverURL,
                transport: TonAPIBroadcastFixtureTransport(
                    responseStatus: .forbidden,
                    expectedServerURL: serverURL,
                    expectedMessageBocBase64: message.bocBase64
                )
            )
        )
        do {
            try await rejectedRemote.broadcast(message: message)
            XCTFail("Expected a non-2xx broadcast response to fail closed")
        } catch {
            XCTAssertFalse(error is CancellationError)
        }
    }

    func testTonAPIReconciliationUsesExactMessageHashPathAndConfirmsExactIntent() async throws {
        let result = try await reconcileTonAPIFixture(
            responseData: try makeTransactionFixtureData()
        )

        XCTAssertEqual(result, .confirmed)
    }

    func testTonAPIReconciliationTreatsOnly404AsNotFound() async throws {
        let errorData = try JSONSerialization.data(
            withJSONObject: ["error": "fixture failure"],
            options: [.sortedKeys]
        )

        let notFoundResult = try await reconcileTonAPIFixture(
            responseData: errorData,
            responseStatus: .notFound
        )
        XCTAssertEqual(notFoundResult, .notFound)

        for status: HTTPResponse.Status in [.badRequest, .forbidden, .internalServerError] {
            do {
                _ = try await reconcileTonAPIFixture(
                    responseData: errorData,
                    responseStatus: status
                )
                XCTFail("Expected HTTP \(status.code) to fail closed")
            } catch {
                XCTAssertEqual(
                    error as? TonTransferRemoteError,
                    .unsupportedAccountState
                )
            }
        }
    }

    func testTonAPIReconciliationFailsClosedForMalformedOrMismatchedTransactions() async throws {
        let differentValidBody = try Builder()
            .store(uint: 1, bits: 1)
            .endCell()
            .toBoc()
            .hexString()
        let rawSender = try TonSwift.Address.parse(Self.sender).toRaw()
        let rawRecipient = try TonSwift.Address.parse(Self.recipient).toRaw()
        typealias Mutation = (inout [String: Any]) -> Void
        let mutations: [(String, Mutation)] = [
            ("account", { transaction in
                var account = transaction["account"] as! [String: Any]
                account["address"] = rawRecipient
                transaction["account"] = account
            }),
            ("type", { $0["transaction_type"] = "TransStorage" }),
            ("success", { $0["success"] = false }),
            ("compute", { transaction in
                var phase = transaction["compute_phase"] as! [String: Any]
                phase["exit_code"] = Int32(1)
                transaction["compute_phase"] = phase
            }),
            ("action", { transaction in
                var phase = transaction["action_phase"] as! [String: Any]
                phase["total_actions"] = Int32(2)
                transaction["action_phase"] = phase
            }),
            ("inbound", { transaction in
                var message = transaction["in_msg"] as! [String: Any]
                message["msg_type"] = "int_msg"
                transaction["in_msg"] = message
            }),
            ("outbound", { transaction in
                var messages = transaction["out_msgs"] as! [[String: Any]]
                var destination = messages[0]["destination"] as! [String: Any]
                destination["address"] = rawSender
                messages[0]["destination"] = destination
                transaction["out_msgs"] = messages
            }),
            ("value", { transaction in
                var messages = transaction["out_msgs"] as! [[String: Any]]
                messages[0]["value"] = Int64(100_000_001)
                transaction["out_msgs"] = messages
            }),
            ("bounce", { transaction in
                var messages = transaction["out_msgs"] as! [[String: Any]]
                messages[0]["bounce"] = false
                transaction["out_msgs"] = messages
            }),
            ("inbound body", { transaction in
                var message = transaction["in_msg"] as! [String: Any]
                message["raw_body"] = differentValidBody
                transaction["in_msg"] = message
            }),
            ("outbound body", { transaction in
                var messages = transaction["out_msgs"] as! [[String: Any]]
                messages[0]["raw_body"] = differentValidBody
                transaction["out_msgs"] = messages
            })
        ]

        for (name, mutation) in mutations {
            do {
                _ = try await reconcileTonAPIFixture(
                    responseData: try makeTransactionFixtureData(mutation: mutation)
                )
                XCTFail("Expected mismatched \(name) to fail closed")
            } catch {
                XCTAssertEqual(
                    error as? TonTransferRemoteError,
                    .unsupportedAccountState,
                    name
                )
            }
        }

        do {
            _ = try await reconcileTonAPIFixture(responseData: Data("{".utf8))
            XCTFail("Expected malformed transaction JSON to fail closed")
        } catch {
            XCTAssertFalse(error is CancellationError)
        }
    }

    func testTonAPIWalletStateMapsLiveNullFieldsAndExactAccountSeqnoPaths() async throws {
        let activeRemote = try makeAccountFixtureRemote(
            address: Self.sender,
            status: "active",
            isWallet: true,
            interfaces: ["wallet_v4r2"],
            sequenceNumber: 9
        )
        let activeState = try await activeRemote.walletState(address: Self.sender)
        XCTAssertEqual(activeState, TonWalletRemoteState(sequenceNumber: 9, isInitialized: true))

        let nonexistRemote = try makeAccountFixtureRemote(
            address: Self.recipient,
            status: "nonexist",
            isWallet: false,
            interfaces: nil,
            sequenceNumber: 0
        )
        let nonexistState = try await nonexistRemote.walletState(address: Self.recipient)
        XCTAssertEqual(nonexistState, TonWalletRemoteState(sequenceNumber: 0, isInitialized: false))
    }

    func testTonAPIWalletAndMemoMappingRejectsExplicitDangerAndPreservesNullContract() async throws {
        for (isScam, isSuspended) in [(true, nil), (nil, true)] as [(Bool?, Bool?)] {
            let remote = try makeAccountFixtureRemote(
                address: Self.sender,
                status: "active",
                isWallet: true,
                interfaces: ["wallet_v4r2"],
                isScam: isScam,
                isSuspended: isSuspended,
                sequenceNumber: 9
            )
            do {
                _ = try await remote.walletState(address: Self.sender)
                XCTFail("Expected explicit danger flag to reject wallet state")
            } catch {
                XCTAssertEqual(error as? TonTransferRemoteError, .unsupportedAccountState)
            }
        }

        for (memoRequired, expected) in [(nil, false), (false, false), (true, true)] as [(Bool?, Bool)] {
            let remote = try makeAccountFixtureRemote(
                address: Self.recipient,
                status: "active",
                isWallet: false,
                interfaces: nil,
                memoRequired: memoRequired,
                sequenceNumber: nil
            )
            let actual = try await remote.recipientRequiresMemo(address: Self.recipient)
            XCTAssertEqual(actual, expected)
        }

        let unsafeRecipient = try makeAccountFixtureRemote(
            address: Self.recipient,
            status: "active",
            isWallet: false,
            interfaces: nil,
            isScam: true,
            sequenceNumber: nil
        )
        do {
            _ = try await unsafeRecipient.recipientRequiresMemo(address: Self.recipient)
            XCTFail("Expected scam recipient to fail closed")
        } catch {
            XCTAssertEqual(error as? TonTransferRemoteError, .unsupportedAccountState)
        }
    }

    func testTonAPIRemoteClientMapsSuccessfulGeneratedClientJSONFixture() async throws {
        let result = try await emulateTonAPIFixture(
            fixtureData: try makeEmulationFixtureData(totalFeeNanotons: 123_456_789)
        )

        XCTAssertEqual(
            result,
            TonEmulationResult(accepted: true, totalFeeNanotons: 123_456_789)
        )
    }

    func testTonAPIRemoteClientAcceptsOmittedTraceChildrenAsNoChildTransactions() async throws {
        let result = try await emulateTonAPIFixture(
            fixtureData: try makeEmulationFixtureData(includeTraceChildren: false)
        )

        XCTAssertEqual(
            result,
            TonEmulationResult(accepted: true, totalFeeNanotons: 123_456)
        )
    }

    func testTonAPIRemoteClientFailsClosedForIncompleteGeneratedClientJSONFixtures() async throws {
        let fixtures = [
            try makeEmulationFixtureData(emulated: nil),
            try makeEmulationFixtureData(includeActionPhase: false),
            try makeEmulationFixtureData(skippedActionCount: 1),
            try makeEmulationFixtureData(computePhaseSkipped: true),
            try makeEmulationFixtureData(traceHasChild: true)
        ]

        for fixture in fixtures {
            let result = try await emulateTonAPIFixture(fixtureData: fixture)

            XCTAssertFalse(result.accepted)
            XCTAssertEqual(result.totalFeeNanotons, 123_456)
        }
    }

    func testTonAPIRemoteClientFailsClosedForMalformedAndMismatchedRawBodies() async throws {
        let differentValidBody = try Builder()
            .store(uint: 1, bits: 1)
            .endCell()
            .toBoc()
            .hexString()
        let fixtures = [
            try makeEmulationFixtureData(inboundRawBodyOverride: "b"),
            try makeEmulationFixtureData(outboundRawBodyOverride: "gg"),
            try makeEmulationFixtureData(inboundRawBodyOverride: "0x00"),
            try makeEmulationFixtureData(inboundRawBodyOverride: differentValidBody),
            try makeEmulationFixtureData(outboundRawBodyOverride: differentValidBody)
        ]

        for fixture in fixtures {
            let result = try await emulateTonAPIFixture(fixtureData: fixture)

            XCTAssertFalse(result.accepted)
            XCTAssertEqual(result.totalFeeNanotons, 123_456)
        }
    }

    func testTonAPIRemoteClientRejectsNegativeAndOversizedFeesFromGeneratedClientJSON() async throws {
        let invalidFees = [
            Int64(-1),
            Int64(TonSendService.defaultMaximumFeeNanotons + 1),
            Int64.max
        ]

        for invalidFee in invalidFees {
            do {
                _ = try await emulateTonAPIFixture(
                    fixtureData: try makeEmulationFixtureData(totalFeeNanotons: invalidFee)
                )
                XCTFail("Expected fee \(invalidFee) to be rejected")
            } catch {
                XCTAssertEqual(error as? TonTransferRemoteError, .invalidFee)
            }
        }
    }

    private func makeService(remote: FakeRemote) -> TonSendService {
        TonSendService(
            remote: remote,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { Self.now }
        )
    }

    private func reconcileTonAPIFixture(
        responseData: Data,
        responseStatus: HTTPResponse.Status = .ok
    ) async throws -> TonReconciliationResult {
        let message = try fixtureSignedMessage()
        let serverURL = try XCTUnwrap(URL(string: "https://ton-api-fixture.invalid"))
        let transport = TonAPIReconciliationFixtureTransport(
            responseData: responseData,
            responseStatus: responseStatus,
            expectedServerURL: serverURL,
            expectedMessageHashHex: message.messageHashHex
        )
        let remote = TonAPIRemoteClient(
            trustedTestClient: Client(serverURL: serverURL, transport: transport)
        )
        return try await remote.reconcile(
            message: message,
            intent: TonEmulationIntent(request: makeRequest())
        )
    }

    private func makeTraceFixtureData(externalMessageBoc: Data) throws -> Data {
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: try makeEmulationFixtureData(externalMessageBoc: externalMessageBoc)
            ) as? [String: Any]
        )
        return try JSONSerialization.data(
            withJSONObject: try XCTUnwrap(payload["trace"]),
            options: [.sortedKeys]
        )
    }

    private func makeTransactionFixtureData(
        mutation: ((inout [String: Any]) -> Void)? = nil
    ) throws -> Data {
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try makeEmulationFixtureData()) as? [String: Any]
        )
        let trace = try XCTUnwrap(payload["trace"] as? [String: Any])
        var transaction = try XCTUnwrap(trace["transaction"] as? [String: Any])
        mutation?(&transaction)
        return try JSONSerialization.data(withJSONObject: transaction, options: [.sortedKeys])
    }

    private func makeAccountFixtureRemote(
        address: String,
        status: String,
        isWallet: Bool,
        interfaces: [String]?,
        isScam: Bool? = nil,
        isSuspended: Bool? = nil,
        memoRequired: Bool? = nil,
        sequenceNumber: Int?
    ) throws -> TonAPIRemoteClient {
        let serverURL = try XCTUnwrap(URL(string: "https://ton-api-fixture.invalid"))
        let accountData = try makeAccountFixtureData(
            address: address,
            status: status,
            isWallet: isWallet,
            interfaces: interfaces,
            isScam: isScam,
            isSuspended: isSuspended,
            memoRequired: memoRequired
        )
        let sequenceData = try sequenceNumber.map {
            try JSONSerialization.data(
                withJSONObject: ["seqno": $0],
                options: [.sortedKeys]
            )
        }
        let transport = TonAPIAccountFixtureTransport(
            accountResponseData: accountData,
            sequenceResponseData: sequenceData,
            expectedServerURL: serverURL,
            expectedAddress: address
        )
        return TonAPIRemoteClient(
            client: Client(serverURL: serverURL, transport: transport)
        )
    }

    private func makeAccountFixtureData(
        address: String,
        status: String,
        isWallet: Bool,
        interfaces: [String]?,
        isScam: Bool?,
        isSuspended: Bool?,
        memoRequired: Bool?
    ) throws -> Data {
        let payload: [String: Any] = [
            "address": address,
            "balance": Int64(0),
            "last_activity": Int64(0),
            "status": status,
            "interfaces": interfaces.map { $0 as Any } ?? NSNull(),
            "is_scam": isScam.map { $0 as Any } ?? NSNull(),
            "memo_required": memoRequired.map { $0 as Any } ?? NSNull(),
            "get_methods": [],
            "is_suspended": isSuspended.map { $0 as Any } ?? NSNull(),
            "is_wallet": isWallet
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    private func emulateTonAPIFixture(fixtureData: Data) async throws -> TonEmulationResult {
        let message = try fixtureSignedMessage()
        let serverURL = try XCTUnwrap(URL(string: "https://ton-api-fixture.invalid"))
        let transport = TonAPIEmulationFixtureTransport(
            responseData: fixtureData,
            expectedServerURL: serverURL,
            expectedMessageBocBase64: message.bocBase64
        )
        let generatedClient = Client(serverURL: serverURL, transport: transport)
        let remote = TonAPIRemoteClient(trustedTestClient: generatedClient)

        return try await remote.emulateSigned(
            message: message,
            intent: TonEmulationIntent(request: makeRequest())
        )
    }

    private func makeEmulationFixtureData(
        emulated: Bool? = true,
        includeActionPhase: Bool = true,
        skippedActionCount: Int32 = 0,
        computePhaseSkipped: Bool = false,
        totalFeeNanotons: Int64 = 123_456,
        includeTraceChildren: Bool = true,
        traceHasChild: Bool = false,
        inboundRawBodyOverride: String? = nil,
        outboundRawBodyOverride: String? = nil,
        externalMessageBoc: Data? = nil
    ) throws -> Data {
        let senderAccount: [String: Any] = [
            "address": try TonSwift.Address.parse(Self.sender).toRaw(),
            "is_scam": false,
            "is_wallet": true
        ]
        let recipientAccount: [String: Any] = [
            "address": try TonSwift.Address.parse(Self.recipient).toRaw(),
            "is_scam": false,
            "is_wallet": false
        ]
        let signedMessage = try fixtureSignedMessage()
        let externalMessage = try Message.loadFrom(
            slice: try XCTUnwrap(
                Cell.fromBoc(src: externalMessageBoc ?? signedMessage.boc).first
            ).beginParse()
        )
        let expectedInboundRawBody = try externalMessage.body.toBoc().hexString()
        let inboundMessage: [String: Any] = [
            "msg_type": "ext_in_msg",
            "created_lt": Int64(1),
            "ihr_disabled": false,
            "bounce": false,
            "bounced": false,
            "value": Int64(0),
            "fwd_fee": Int64(0),
            "ihr_fee": Int64(0),
            "destination": senderAccount,
            "import_fee": Int64(0),
            "created_at": Int64(1),
            "raw_body": inboundRawBodyOverride ?? expectedInboundRawBody
        ]
        let commentBody = try Builder()
            .store(int: 0, bits: 32)
            .writeSnakeData(Data("Fearless TON".utf8))
            .endCell()
        let expectedOutboundRawBody = try commentBody.toBoc().hexString()
        let message: [String: Any] = [
            "msg_type": "int_msg",
            "created_lt": Int64(2),
            "ihr_disabled": true,
            "bounce": true,
            "bounced": false,
            "value": Int64(100_000_000),
            "fwd_fee": Int64(1),
            "ihr_fee": Int64(0),
            "destination": recipientAccount,
            "source": senderAccount,
            "import_fee": Int64(0),
            "created_at": Int64(1),
            "raw_body": outboundRawBodyOverride ?? expectedOutboundRawBody
        ]
        var transaction: [String: Any] = [
            "hash": "fixture-transaction-hash",
            "lt": Int64(2),
            "account": senderAccount,
            "success": true,
            "utime": Int64(Self.now),
            "orig_status": "active",
            "end_status": "active",
            "total_fees": totalFeeNanotons,
            "transaction_type": "TransOrd",
            "state_update_old": "fixture-old-state",
            "state_update_new": "fixture-new-state",
            "in_msg": inboundMessage,
            "out_msgs": [message],
            "block": "(-1,8000000000000000,1)",
            "compute_phase": [
                "skipped": computePhaseSkipped,
                "success": !computePhaseSkipped,
                "gas_fees": Int64(1),
                "gas_used": Int64(1),
                "vm_steps": UInt32(1),
                "exit_code": Int32(0)
            ],
            "aborted": false,
            "destroyed": false
        ]
        if includeActionPhase {
            transaction["action_phase"] = [
                "success": true,
                "total_actions": Int32(1),
                "skipped_actions": skippedActionCount,
                "fwd_fees": Int64(1),
                "total_fees": Int64(1)
            ]
        }

        var trace: [String: Any] = [
            "transaction": transaction,
            "interfaces": ["wallet_v4r2"]
        ]
        if let emulated {
            trace["emulated"] = emulated
        }
        if includeTraceChildren {
            trace["children"] = traceHasChild ? [trace] : []
        }

        let payload: [String: Any] = [
            "trace": trace,
            "risk": [
                "transfer_all_remaining_balance": false,
                "ton": Int64(100_000_000),
                "jettons": [],
                "nfts": []
            ],
            "event": [
                "event_id": "fixture-event-id",
                "timestamp": Int64(Self.now),
                "actions": [
                    [
                        "type": "TonTransfer",
                        "status": "ok",
                        "simple_preview": [
                            "name": "TON transfer",
                            "description": "Fixture native TON transfer",
                            "accounts": [senderAccount]
                        ]
                    ]
                ],
                "account": senderAccount,
                "is_scam": false,
                "lt": Int64(2),
                "in_progress": false,
                "extra": Int64(0)
            ]
        ]

        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    private func fixtureSignedMessage() throws -> TonSignedExternalMessage {
        try TonTransferTransactionBuilder.buildAndSign(
            request: TonTransferTransactionRequest(
                senderAddress: Self.sender,
                recipientAddress: Self.recipient,
                amountNanotons: "100000000",
                sequenceNumber: 9,
                includeStateInit: false,
                validUntil: Self.now + 120,
                bounce: true,
                comment: "Fearless TON"
            ),
            privateKeySeed: Self.account.privateKey,
            now: Self.now
        )
    }

    private func fixtureUnsignedMessage() throws -> TonUnsignedEmulationMessage {
        try TonTransferTransactionBuilder.buildForFeeEstimation(
            request: TonTransferTransactionRequest(
                senderAddress: Self.sender,
                recipientAddress: Self.recipient,
                amountNanotons: "100000000",
                sequenceNumber: 9,
                includeStateInit: false,
                validUntil: Self.now + 120,
                bounce: true,
                comment: "Fearless TON"
            ),
            publicKey: Self.account.publicKey,
            now: Self.now
        )
    }

    private func makeRequest(
        asset: TonTransferAsset = .nativeTon,
        network: TonTransferNetwork = .mainnet,
        mnemonic: String = TonSendServiceTests.mnemonic,
        senderAddress: String = TonSendServiceTests.sender,
        recipientAddress: String = TonSendServiceTests.recipient,
        amountNanotons: String = "100000000",
        bounce: Bool = true,
        comment: String? = "Fearless TON"
    ) -> TonNativeSendRequest {
        TonNativeSendRequest(
            asset: asset,
            network: network,
            mnemonic: mnemonic,
            senderAddress: senderAddress,
            recipientAddress: recipientAddress,
            amountNanotons: amountNanotons,
            bounce: bounce,
            comment: comment
        )
    }

    private func makeEstimateRequest(
        asset: TonTransferAsset = .nativeTon,
        network: TonTransferNetwork = .mainnet,
        publicKey: Data = TonSendServiceTests.account.publicKey,
        senderAddress: String = TonSendServiceTests.sender,
        recipientAddress: String = TonSendServiceTests.recipient,
        amountNanotons: String = "100000000",
        bounce: Bool = true,
        comment: String? = "Fearless TON"
    ) -> TonNativeEstimateRequest {
        TonNativeEstimateRequest(
            asset: asset,
            network: network,
            publicKey: publicKey,
            senderAddress: senderAddress,
            recipientAddress: recipientAddress,
            amountNanotons: amountNanotons,
            bounce: bounce,
            comment: comment
        )
    }

    private func sendError(
        service: TonSendService,
        request: TonNativeSendRequest
    ) async -> Error? {
        do {
            _ = try await service.sendUnquotedForTesting(request)
            XCTFail("Expected TON send to fail")
            return nil
        } catch {
            return error
        }
    }

    private func sendError(
        quotedService service: TonSendService,
        request: TonNativeSendRequest,
        quote: TonTransferFeeQuote?
    ) async -> Error? {
        do {
            _ = try await service.send(request, feeQuote: quote)
            XCTFail("Expected quoted TON send to fail")
            return nil
        } catch {
            return error
        }
    }

    private func assertUnknownOutcome(
        _ error: Error?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let serviceError = error as? TonSendServiceError else {
            XCTFail("Expected typed TON unknown outcome, got \(String(describing: error))", file: file, line: line)
            return
        }
        guard case let .broadcastOutcomeUnknown(messageHashHex) = serviceError else {
            XCTFail("Expected TON unknown outcome, got \(serviceError)", file: file, line: line)
            return
        }
        XCTAssertEqual(messageHashHex.count, 64, file: file, line: line)
    }

    private func unknownOutcomeHash(
        _ error: Error?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String? {
        guard let serviceError = error as? TonSendServiceError,
              case let .broadcastOutcomeUnknown(messageHashHex) = serviceError
        else {
            XCTFail("Expected typed TON unknown outcome", file: file, line: line)
            return nil
        }
        XCTAssertEqual(messageHashHex.count, 64, file: file, line: line)
        return messageHashHex
    }

    private final class LockedClock: @unchecked Sendable {
        private let lock = NSLock()
        private var storedValue: UInt64

        init(_ value: UInt64) {
            storedValue = value
        }

        var value: UInt64 {
            get {
                lock.lock()
                defer { lock.unlock() }
                return storedValue
            }
            set {
                lock.lock()
                storedValue = newValue
                lock.unlock()
            }
        }
    }

    private final class FailOnSaveJournal: TonPendingIntentJournaling, @unchecked Sendable {
        func load(senderRaw _: String) throws -> TonPendingSignedIntent? { nil }

        func save(_: TonPendingSignedIntent) throws {
            throw TonPendingIntentJournalError.unavailable
        }

        func delete(senderRaw _: String, expectedMessageHashHex _: String) throws {
            throw TonPendingIntentJournalError.unavailable
        }
    }

    private final class FakeRemote: TonTransferRemoteProtocol, @unchecked Sendable {
        var reviewedSignedOperationOrigin: String? = TonAPIClientFactory.canonicalAuthenticatedOrigin.absoluteString

        enum Stage: Equatable {
            case recipientInspection
            case walletState
            case emulate
            case broadcast
            case reconcile
        }

        enum Failure: Error {
            case injected
        }

        var walletState = TonWalletRemoteState(sequenceNumber: 9, isInitialized: true)
        var emulation = TonEmulationResult(accepted: true, totalFeeNanotons: 100)
        var memoRequired = false
        var reconciliation: TonReconciliationResult?
        var failureStage: Stage?
        var suspendedStage: Stage?
        var nonResumingStage: Stage?
        var walletStateStarted: (() -> Void)?
        var emulateStarted: (() -> Void)?
        private(set) var recipientInspectionAddresses: [String] = []
        private(set) var walletAddresses: [String] = []
        private(set) var emulatedBocs: [String] = []
        private(set) var broadcastBocs: [String] = []
        private(set) var reconciledBocs: [String] = []
        private(set) var callOrder: [String] = []
        private(set) var unsignedEmulationCount = 0
        private(set) var signedEmulationCount = 0
        private var broadcastSucceeded = false

        func walletState(address: String) async throws -> TonWalletRemoteState {
            callOrder.append("walletState")
            walletAddresses.append(address)
            walletStateStarted?()
            try await pauseOrFail(stage: .walletState)
            return walletState
        }

        func recipientRequiresMemo(address: String) async throws -> Bool {
            recipientInspectionAddresses.append(address)
            try await pauseOrFail(stage: .recipientInspection)
            return memoRequired
        }

        func emulateUnsigned(
            message: TonUnsignedEmulationMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonEmulationResult {
            unsignedEmulationCount += 1
            callOrder.append("emulate")
            emulatedBocs.append(message.bocBase64)
            emulateStarted?()
            try await pauseOrFail(stage: .emulate)
            return emulation
        }

        func emulateSigned(
            message: TonSignedExternalMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonEmulationResult {
            signedEmulationCount += 1
            callOrder.append("emulate")
            emulatedBocs.append(message.bocBase64)
            emulateStarted?()
            try await pauseOrFail(stage: .emulate)
            return emulation
        }

        func broadcast(message: TonSignedExternalMessage) async throws {
            callOrder.append("broadcast")
            broadcastBocs.append(message.bocBase64)
            try await pauseOrFail(stage: .broadcast)
            broadcastSucceeded = true
        }

        func reconcile(
            message: TonSignedExternalMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonReconciliationResult {
            reconciledBocs.append(message.bocBase64)
            try await pauseOrFail(stage: .reconcile)
            return reconciliation ?? (broadcastSucceeded ? .confirmed : .notFound)
        }

        private func pauseOrFail(stage: Stage) async throws {
            if failureStage == stage {
                throw Failure.injected
            }
            if nonResumingStage == stage {
                await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
            }
            if suspendedStage == stage {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }
}
#else
final class TonSendServiceReleasePolicyTests: XCTestCase {
    func testReleaseSendFailsBeforeAnyValidationOrRemoteWork() async {
        let remote = RejectingRemote()
        let service = TonSendService(
            remote: remote,
            clock: { 1_700_000_000 }
        )
        let request = TonNativeSendRequest(
            mnemonic: "intentionally invalid",
            senderAddress: "intentionally invalid",
            recipientAddress: "intentionally invalid",
            amountNanotons: "intentionally invalid",
            bounce: false
        )

        let caughtError: Error?
        do {
            _ = try await service.send(request)
            caughtError = nil
        } catch {
            caughtError = error
        }

        XCTAssertEqual(caughtError as? TonSendServiceError, .productionSendDisabled)
        let remoteCallCount = await remote.callCount
        XCTAssertEqual(remoteCallCount, 0)
    }

    private actor RejectingRemote: TonTransferRemoteProtocol {
        enum UnexpectedRemoteCall: Error {
            case invoked
        }

        private(set) var callCount = 0

        func walletState(address _: String) async throws -> TonWalletRemoteState {
            callCount += 1
            throw UnexpectedRemoteCall.invoked
        }

        func recipientRequiresMemo(address _: String) async throws -> Bool {
            callCount += 1
            throw UnexpectedRemoteCall.invoked
        }

        func emulateUnsigned(
            message _: TonUnsignedEmulationMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonEmulationResult {
            callCount += 1
            throw UnexpectedRemoteCall.invoked
        }

        func emulateSigned(
            message _: TonSignedExternalMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonEmulationResult {
            callCount += 1
            throw UnexpectedRemoteCall.invoked
        }

        func broadcast(message _: TonSignedExternalMessage) async throws {
            callCount += 1
            throw UnexpectedRemoteCall.invoked
        }

        func reconcile(
            message _: TonSignedExternalMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonReconciliationResult {
            callCount += 1
            throw UnexpectedRemoteCall.invoked
        }
    }
}
#endif

private struct TonAPIEmulationFixtureTransport: ClientTransport {
    enum FixtureError: Error {
        case unexpectedRequest
    }

    let responseData: Data
    let expectedServerURL: URL
    let expectedMessageBocBase64: String

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard
            operationID == "emulateMessageToWallet",
            request.method == .post,
            request.path == "/v2/wallet/emulate",
            baseURL == expectedServerURL,
            let body
        else {
            throw FixtureError.unexpectedRequest
        }

        let requestData = try await Data(collecting: body, upTo: 1_024)
        let requestJSON = try JSONSerialization.jsonObject(with: requestData) as? [String: Any]
        guard requestJSON?["boc"] as? String == expectedMessageBocBase64 else {
            throw FixtureError.unexpectedRequest
        }

        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        return (
            HTTPResponse(status: .ok, headerFields: headers),
            HTTPBody(responseData)
        )
    }
}

private struct TonAPIUnsignedEmulationFixtureTransport: ClientTransport {
    enum FixtureError: Error {
        case unexpectedRequest
    }

    let responseData: Data
    let expectedServerURL: URL
    let expectedMessageBocBase64: String

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard operationID == "emulateMessageToTrace",
              request.method == .post,
              request.path == "/v2/traces/emulate?ignore_signature_check=true",
              baseURL == expectedServerURL,
              let body
        else {
            throw FixtureError.unexpectedRequest
        }

        let requestData = try await Data(collecting: body, upTo: 16384)
        let requestJSON = try JSONSerialization.jsonObject(with: requestData) as? [String: Any]
        guard requestJSON?.count == 1,
              requestJSON?["boc"] as? String == expectedMessageBocBase64
        else {
            throw FixtureError.unexpectedRequest
        }

        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        return (
            HTTPResponse(status: .ok, headerFields: headers),
            HTTPBody(responseData)
        )
    }
}

private struct TonAPIBroadcastFixtureTransport: ClientTransport {
    enum FixtureError: Error {
        case unexpectedRequest
    }

    let responseStatus: HTTPResponse.Status
    let expectedServerURL: URL
    let expectedMessageBocBase64: String

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard operationID == "sendBlockchainMessage",
              request.method == .post,
              request.path == "/v2/blockchain/message",
              baseURL == expectedServerURL,
              let body
        else {
            throw FixtureError.unexpectedRequest
        }

        let requestData = try await Data(collecting: body, upTo: 16_384)
        let requestJSON = try JSONSerialization.jsonObject(with: requestData) as? [String: Any]
        guard requestJSON?.count == 1,
              requestJSON?["boc"] as? String == expectedMessageBocBase64
        else {
            throw FixtureError.unexpectedRequest
        }

        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        let responseData = try JSONSerialization.data(
            withJSONObject: ["error": "fixture rejection"],
            options: [.sortedKeys]
        )
        return (
            HTTPResponse(status: responseStatus, headerFields: headers),
            responseStatus == .ok ? nil : HTTPBody(responseData)
        )
    }
}

private struct TonAPIReconciliationFixtureTransport: ClientTransport {
    enum FixtureError: Error {
        case unexpectedRequest
    }

    let responseData: Data
    let responseStatus: HTTPResponse.Status
    let expectedServerURL: URL
    let expectedMessageHashHex: String

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard operationID == "getBlockchainTransactionByMessageHash",
              request.method == .get,
              request.path == "/v2/blockchain/messages/\(expectedMessageHashHex)/transaction",
              baseURL == expectedServerURL,
              body == nil
        else {
            throw FixtureError.unexpectedRequest
        }

        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        return (
            HTTPResponse(status: responseStatus, headerFields: headers),
            HTTPBody(responseData)
        )
    }
}

private struct TonAPIAccountFixtureTransport: ClientTransport {
    enum FixtureError: Error {
        case unexpectedRequest
    }

    let accountResponseData: Data
    let sequenceResponseData: Data?
    let expectedServerURL: URL
    let expectedAddress: String

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard request.method == .get,
              baseURL == expectedServerURL,
              body == nil
        else {
            throw FixtureError.unexpectedRequest
        }

        let responseData: Data
        switch operationID {
        case "getAccount":
            guard request.path == "/v2/accounts/\(expectedAddress)" else {
                throw FixtureError.unexpectedRequest
            }
            responseData = accountResponseData
        case "getAccountSeqno":
            guard request.path == "/v2/wallet/\(expectedAddress)/seqno",
                  let sequenceResponseData
            else {
                throw FixtureError.unexpectedRequest
            }
            responseData = sequenceResponseData
        default:
            throw FixtureError.unexpectedRequest
        }

        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        return (
            HTTPResponse(status: .ok, headerFields: headers),
            HTTPBody(responseData)
        )
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else {
            return nil
        }

        var data = Data(capacity: hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let end = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index ..< end], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = end
        }
        self = data
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
