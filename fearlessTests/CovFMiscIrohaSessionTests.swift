import XCTest
@testable import fearless

/// Drives `IrohaConnectSessionService` over an in-memory relay with the recorded web session.
final class CovFMiscIrohaSessionTests: XCTestCase {
    private typealias Vectors = IrohaConnectWebVectors

    private final class DelegateSpy: IrohaConnectSessionServiceDelegate {
        var connections: [(IrohaConnectOpenFrame, IrohaConnectAccountDescriptor)] = []
        var approvals = 0
        var signatures: [IrohaConnectPendingSignature] = []
        var completions = 0
        var notices: [IrohaConnectNotice] = []
        var closes: [Error?] = []

        func irohaConnectSession(
            _: IrohaConnectSessionService,
            requestsConnection open: IrohaConnectOpenFrame,
            account: IrohaConnectAccountDescriptor
        ) {
            connections.append((open, account))
        }

        func irohaConnectSessionDidApprove(_: IrohaConnectSessionService) {
            approvals += 1
        }

        func irohaConnectSession(_: IrohaConnectSessionService, requestsSignature request: IrohaConnectPendingSignature) {
            signatures.append(request)
        }

        func irohaConnectSessionDidCompleteSignature(_: IrohaConnectSessionService) {
            completions += 1
        }

        func irohaConnectSession(_: IrohaConnectSessionService, didRefuse notice: IrohaConnectNotice) {
            notices.append(notice)
        }

        func irohaConnectSession(_: IrohaConnectSessionService, didCloseWith error: Error?) {
            closes.append(error)
        }
    }

    private struct Fixture {
        let service: IrohaConnectSessionService
        let transport: IrohaConnectFakeTransport
        let signer: IrohaConnectFixedSigner
        let delegate: DelegateSpy
    }

    private var appFrames: [Data] {
        Vectors.transcript.filter { $0.direction == "app-to-wallet" }.map(\.frame)
    }

    private var walletFrames: [Data] {
        Vectors.transcript.filter { $0.direction == "wallet-to-app" }.map(\.frame)
    }

    func testErrorsDescribeEveryFailureDistinctly() {
        let errors: [IrohaConnectSessionServiceError] = [.transportUnavailable, .authenticationFailed, .connectTimedOut, .unexpectedMessage]
        let descriptions = errors.compactMap(\.errorDescription)
        XCTAssertEqual(Set(descriptions).count, errors.count)
        XCTAssertNil(IrohaConnectSessionServiceError.closedByApp.errorDescription)
    }

    func testRecordedSession_whenApprovedThroughTheService_thenSendsTheWebWalletsFrames() throws {
        let fixture = makeFixture()
        fixture.service.start()
        XCTAssertTrue(CovJWait.until { fixture.transport.openCount == 1 })
        fixture.transport.onOpen?(fixture.service.handoff.webSocketSubprotocol)

        fixture.transport.onMessage?(appFrames[0])
        XCTAssertTrue(CovJWait.until { fixture.delegate.connections.count == 1 })
        XCTAssertEqual(fixture.delegate.connections.first?.1, Vectors.sessionAccount)

        fixture.service.approveConnection(for: Vectors.sessionAccount)
        XCTAssertTrue(CovJWait.until { fixture.delegate.approvals == 1 })
        XCTAssertEqual(fixture.transport.sent, [walletFrames[0]])

        fixture.transport.onMessage?(appFrames[1])
        XCTAssertTrue(CovJWait.until { fixture.delegate.signatures.count == 1 })
        let request = try XCTUnwrap(fixture.delegate.signatures.first)
        XCTAssertEqual(request.review.transfer?.quantity, "0.001")
        fixture.service.approveSignature(requestID: request.requestID)
        XCTAssertTrue(CovJWait.until { fixture.delegate.completions == 1 })
        XCTAssertEqual(fixture.transport.sent, Array(walletFrames[0 ... 1]))
        // The account key signed the wallet-built approval preimage and the reviewed payload hash, nothing else.
        XCTAssertEqual(fixture.signer.signedMessages.count, 2)
        XCTAssertEqual(fixture.signer.signedMessages.last, request.payloadHash)

        fixture.transport.onMessage?(appFrames[2])
        XCTAssertTrue(CovJWait.until { fixture.delegate.signatures.count == 2 })
        fixture.service.rejectSignature(requestID: fixture.delegate.signatures[1].requestID)
        XCTAssertTrue(CovJWait.until { fixture.transport.sent.count == 3 })
        XCTAssertEqual(fixture.transport.sent[2], walletFrames[2])

        fixture.transport.onMessage?(appFrames[3])
        XCTAssertTrue(CovJWait.until { fixture.delegate.notices == [.rawSigningUnavailable] })
        XCTAssertEqual(fixture.transport.sent[3], walletFrames[3])
        XCTAssertEqual(fixture.signer.signedMessages.count, 2)

        // The app's pong (to the web wallet's keepalive) keeps the app sequence; its encrypted Close ends the
        // session quietly.
        fixture.transport.onMessage?(appFrames[4])
        fixture.transport.onMessage?(appFrames[5])
        XCTAssertTrue(CovJWait.until { fixture.delegate.closes.count == 1 })
        XCTAssertNil(fixture.delegate.closes.first ?? nil)
        XCTAssertEqual(fixture.transport.closeCount, 1)
    }

    func testKeepAlive_whenTheSessionIsOpen_thenSendsBinaryConnectPings() throws {
        let fixture = makeFixture(timings: IrohaConnectSessionTimings(connectTimeout: 20, keepAliveInterval: 0.05, requestTimeToLive: 120))
        try openAndApprove(fixture)
        XCTAssertTrue(CovJWait.until(timeout: 3) { fixture.transport.sent.count >= 4 })
        let frames = fixture.transport.sent.map(Self.summary)
        // One Approve, every other frame a Connect Ping, all in one strict wallet sequence.
        XCTAssertEqual(frames.map(\.sequence), Array(1 ... UInt64(frames.count)))
        XCTAssertEqual(frames.filter { $0.controlTag == 1 }.count, 1)
        XCTAssertEqual(frames.filter { $0.controlTag == 4 }.count, frames.count - 1)
        fixture.service.close()
        XCTAssertTrue(CovJWait.until { fixture.delegate.closes.count == 1 })
    }

    /// Sequence and control tag of a wallet control frame (sid and direction are fixed-size).
    private static func summary(_ frame: Data) -> (sequence: UInt64, controlTag: UInt32) {
        let bytes = [UInt8](frame)
        let sequence = (0 ..< 8).reduce(UInt64(0)) { $0 | UInt64(bytes[316 + $1]) << (8 * UInt64($1)) }
        let tag = (0 ..< 4).reduce(UInt32(0)) { $0 | UInt32(bytes[344 + $1]) << (8 * UInt32($1)) }
        return (sequence, tag)
    }

    func testRequestTimeout_whenThePersonDoesNotAnswer_thenTellsTheAppAndKeepsTheSession() throws {
        let fixture = makeFixture(timings: IrohaConnectSessionTimings(connectTimeout: 20, keepAliveInterval: 60, requestTimeToLive: 0.1))
        try openAndApprove(fixture)
        fixture.transport.onMessage?(appFrames[1])
        XCTAssertTrue(CovJWait.until { fixture.delegate.signatures.count == 1 })
        XCTAssertTrue(CovJWait.until(timeout: 3) { fixture.delegate.notices == [.requestExpired] })
        XCTAssertEqual(fixture.transport.sent.count, 2)
        XCTAssertTrue(fixture.delegate.closes.isEmpty)

        // A late approval of the expired request is refused and nothing is signed.
        let signed = fixture.signer.signedMessages.count
        fixture.service.approveSignature(requestID: fixture.delegate.signatures[0].requestID)
        XCTAssertTrue(CovJWait.until { fixture.delegate.closes.count == 1 })
        XCTAssertEqual(fixture.signer.signedMessages.count, signed)
    }

    func testConnectTimeout_whenTheAppNeverOpens_thenFails() {
        let fixture = makeFixture(timings: IrohaConnectSessionTimings(connectTimeout: 0.1, keepAliveInterval: 60, requestTimeToLive: 120))
        fixture.service.start()
        XCTAssertTrue(CovJWait.until(timeout: 3) { fixture.delegate.closes.count == 1 })
        XCTAssertEqual(fixture.delegate.closes.first as? IrohaConnectSessionServiceError, .connectTimedOut)
    }

    func testTransport_whenItMisbehaves_thenTheSessionEnds() {
        let cases: [(String, (IrohaConnectFakeTransport) -> Void, IrohaConnectSessionServiceError?)] = [
            ("another subprotocol", { $0.onOpen?("chat") }, .authenticationFailed),
            ("a text frame", { $0.onTextMessage?() }, .unexpectedMessage),
            ("a dropped socket", { $0.onClose?(nil) }, .transportUnavailable)
        ]
        for (name, act, expected) in cases {
            let fixture = makeFixture()
            fixture.service.start()
            XCTAssertTrue(CovJWait.until { fixture.transport.openCount == 1 }, name)
            act(fixture.transport)
            XCTAssertTrue(CovJWait.until { fixture.delegate.closes.count == 1 }, name)
            XCTAssertEqual(fixture.delegate.closes.first as? IrohaConnectSessionServiceError, expected, name)
        }

        // A relay that selects no subprotocol is accepted.
        let fixture = makeFixture()
        fixture.service.start()
        XCTAssertTrue(CovJWait.until { fixture.transport.openCount == 1 })
        fixture.transport.onOpen?(nil)
        fixture.transport.onMessage?(appFrames[0])
        XCTAssertTrue(CovJWait.until { fixture.delegate.connections.count == 1 })
        XCTAssertTrue(fixture.delegate.closes.isEmpty)
    }

    func testRejectConnection_whenThePersonDeclines_thenSendsUserRejectedAndCloses() throws {
        let fixture = makeFixture()
        fixture.service.start()
        XCTAssertTrue(CovJWait.until { fixture.transport.openCount == 1 })
        fixture.transport.onMessage?(appFrames[0])
        XCTAssertTrue(CovJWait.until { fixture.delegate.connections.count == 1 })

        fixture.service.rejectConnection()

        XCTAssertTrue(CovJWait.until { fixture.delegate.closes.count == 1 })
        let frame = try IrohaConnectWireCodec.decodeFrame(XCTUnwrap(fixture.transport.sent.first), sessionID: fixture.service.handoff.sessionID)
        guard case let .control(.reject(code, codeID, _)) = frame.kind else {
            return XCTFail("expected Reject")
        }
        XCTAssertEqual(code, 4001)
        XCTAssertEqual(codeID, "user_rejected")
        XCTAssertTrue(fixture.signer.signedMessages.isEmpty)
    }

    func testApproval_whenTheAccountChangedOrNoAccountExists_thenNothingIsSigned() {
        let changed = makeFixture()
        changed.service.start()
        XCTAssertTrue(CovJWait.until { changed.transport.openCount == 1 })
        changed.transport.onMessage?(appFrames[0])
        XCTAssertTrue(CovJWait.until { changed.delegate.connections.count == 1 })
        changed.service.approveConnection(for: IrohaConnectAccountDescriptor(walletName: "Other", accountID: "other", publicKey: Data(count: 32)))
        XCTAssertTrue(CovJWait.until { changed.delegate.closes.count == 1 })
        XCTAssertEqual(changed.delegate.closes.first as? IrohaConnectAccountProviderError, .accountMismatch)
        XCTAssertTrue(changed.signer.signedMessages.isEmpty)

        let missing = makeFixture()
        missing.signer.selectionError = IrohaConnectAccountProviderError.accountUnavailable
        missing.service.start()
        XCTAssertTrue(CovJWait.until { missing.transport.openCount == 1 })
        missing.transport.onMessage?(appFrames[0])
        XCTAssertTrue(CovJWait.until { missing.delegate.closes.count == 1 })
        XCTAssertEqual(missing.delegate.closes.first as? IrohaConnectAccountProviderError, .accountUnavailable)
        XCTAssertTrue(missing.delegate.connections.isEmpty)
    }

    func testClose_whenConnected_thenSealsAWalletCloseBeforeTheSocketCloses() throws {
        let fixture = makeFixture()
        try openAndApprove(fixture)

        fixture.service.close()

        XCTAssertTrue(CovJWait.until { fixture.delegate.closes.count == 1 })
        XCTAssertNil(fixture.delegate.closes.first ?? nil)
        let last = try IrohaConnectWireCodec.decodeFrame(XCTUnwrap(fixture.transport.sent.last), sessionID: fixture.service.handoff.sessionID)
        guard case .ciphertext = last.kind else {
            return XCTFail("expected the sealed Close")
        }
        XCTAssertEqual(fixture.transport.closeCount, 1)
    }

    // MARK: - Helpers

    private func makeFixture(timings: IrohaConnectSessionTimings = IrohaConnectSessionTimings()) -> Fixture {
        let transport = IrohaConnectFakeTransport()
        let account = Vectors.sessionAccount
        let walletFrames = walletFrames
        let walletKeyPair = { () -> IrohaConnectWalletKeyPair in
            // swiftlint:disable:next force_try
            try! IrohaConnectWalletKeyPair(rawPrivateKey: Vectors.bytes("session", "walletPrivateKeyHex"))
        }
        let signer = IrohaConnectFixedSigner(account: account)
        // The web wallet's signatures, keyed by the bytes the iOS wallet must ask to sign.
        let engine = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        _ = try? engine.receive(appFrames[0]) { account }
        if let preimage = try? engine.approvalPreimage(walletKeyPair: walletKeyPair()) {
            signer.signatures[preimage] = Vectors.approveSignature(walletFrames[0])
        }
        signer.signatures[Data(irohaConnectHex: Vectors.string("session", "transferPayloadHashHex")) ?? Data()] =
            Vectors.bytes("session", "transferSignatureHex")
        let service = IrohaConnectSessionService(
            handoff: Vectors.sessionLink,
            accountProvider: signer,
            transport: transport,
            timings: timings,
            makeWalletKeyPair: walletKeyPair,
            makeRequestID: { UUID().uuidString }
        )
        let delegate = DelegateSpy()
        service.delegate = delegate
        return Fixture(service: service, transport: transport, signer: signer, delegate: delegate)
    }

    private func openAndApprove(_ fixture: Fixture) throws {
        fixture.service.start()
        XCTAssertTrue(CovJWait.until { fixture.transport.openCount == 1 })
        fixture.transport.onMessage?(appFrames[0])
        XCTAssertTrue(CovJWait.until { fixture.delegate.connections.count == 1 })
        fixture.service.approveConnection(for: Vectors.sessionAccount)
        XCTAssertTrue(CovJWait.until { fixture.delegate.approvals == 1 })
    }
}

/// Live pairing on https://taira.sora.org, run inside the simulator test host. The dApp side is the upstream
/// iroha-js 0.0.3 app SDK (`build/reports/ios-iroha-connect-v1-20261121/vectors/iroha-connect-ios-live.spec.ts`
/// in the workspace), which writes its wallet link to `$IROHA_CONNECT_LIVE_DIR/wallet-uri.txt`. Skipped unless
/// `TEST_RUNNER_IROHA_CONNECT_LIVE_DIR` is set; nothing is submitted to the chain.
final class IrohaConnectLiveTairaTests: XCTestCase {
    private final class LiveDelegate: IrohaConnectSessionServiceDelegate {
        var log: [String] = []
        var closed = false
        var closeError: Error?
        var signatures: [IrohaConnectPendingSignature] = []
        var notices: [IrohaConnectNotice] = []
        var onConnection: ((IrohaConnectAccountDescriptor) -> Void)?
        var onSignature: ((IrohaConnectPendingSignature) -> Void)?

        func irohaConnectSession(
            _: IrohaConnectSessionService,
            requestsConnection open: IrohaConnectOpenFrame,
            account: IrohaConnectAccountDescriptor
        ) {
            log.append("open app=\(open.appMetadata?.name ?? "-") methods=\(open.permissions?.methods ?? [])")
            onConnection?(account)
        }

        func irohaConnectSessionDidApprove(_: IrohaConnectSessionService) {
            log.append("approved")
        }

        func irohaConnectSession(_: IrohaConnectSessionService, requestsSignature request: IrohaConnectPendingSignature) {
            log.append("review kind=\(request.review.kind.rawValue) hash=\(request.payloadHash.irohaConnectHex)")
            signatures.append(request)
            onSignature?(request)
        }

        func irohaConnectSessionDidCompleteSignature(_: IrohaConnectSessionService) {
            log.append("signature answered")
        }

        func irohaConnectSession(_: IrohaConnectSessionService, didRefuse notice: IrohaConnectNotice) {
            log.append("refused \(notice.rawValue)")
            notices.append(notice)
        }

        func irohaConnectSession(_: IrohaConnectSessionService, didCloseWith error: Error?) {
            log.append("closed \(error.map { "\($0)" } ?? "cleanly")")
            closed = true
            closeError = error
        }
    }

    func testLivePairing_whenTheAppSDKOpensASessionOnTaira_thenTheWalletPairsReviewsAndSigns() throws {
        guard let directory = ProcessInfo.processInfo.environment["IROHA_CONNECT_LIVE_DIR"], !directory.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_IROHA_CONNECT_LIVE_DIR to run the live Taira pairing.")
        }
        let linkFile = URL(fileURLWithPath: directory).appendingPathComponent("wallet-uri.txt")
        XCTAssertTrue(CovJWait.until(timeout: 120) { FileManager.default.fileExists(atPath: linkFile.path) })
        let link = try IrohaConnectWalletURI.parse(String(contentsOf: linkFile).trimmingCharacters(in: .whitespacesAndNewlines))

        // The real account provider with key material derived by the app's own Iroha derivation.
        let derived = try IrohaKeyDerivation.deriveAddress(
            mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            chainDiscriminant: link.profile.networkPrefix
        )
        let descriptor = IrohaConnectAccountDescriptor(
            walletName: "Live",
            accountID: derived.i105,
            publicKey: derived.account.publicKey
        )
        let provider = KeychainIrohaConnectAccountProvider(
            policy: .production,
            descriptorLoader: { descriptor },
            materialLoader: { (descriptor, derived.account.privateKey) }
        )
        let service = IrohaConnectSessionService(handoff: link, accountProvider: provider)
        let delegate = LiveDelegate()
        delegate.onConnection = { [weak service] account in service?.approveConnection(for: account) }
        delegate.onSignature = { [weak service] request in
            // Approve the transfer the person reviewed; decline the contract call.
            if request.review.kind == .transfer {
                service?.approveSignature(requestID: request.requestID)
            } else {
                service?.rejectSignature(requestID: request.requestID)
            }
        }
        service.delegate = delegate
        service.start()

        XCTAssertTrue(CovJWait.until(timeout: 600) { delegate.closed })
        let evidence: [String: Any] = [
            "accountId": descriptor.accountID,
            "log": delegate.log,
            "closeError": delegate.closeError.map { "\($0)" } ?? NSNull()
        ]
        let data = try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("ios-evidence.json"))

        XCTAssertNil(delegate.closeError)
        let transfer = try XCTUnwrap(delegate.signatures.first { $0.review.kind == .transfer })
        XCTAssertEqual(transfer.review.transfer?.quantity, "0.001")
        XCTAssertEqual(transfer.review.authority, descriptor.accountID)
        XCTAssertTrue(delegate.signatures.contains { $0.review.kind == .contractCalls })
        XCTAssertEqual(delegate.notices, [.rawSigningUnavailable])
    }
}
