import CryptoKit
import XCTest
@testable import fearless

final class IrohaConnectProtocolTests: XCTestCase {
    private typealias Vectors = IrohaConnectWebVectors

    // MARK: - Primitives and network

    func testCRC64_whenNoritoCheckInput_thenMatchesWeb() {
        XCTAssertEqual(String(IrohaConnectNorito.crc64(Data("123456789".utf8)), radix: 16), Vectors.string("primitives", "crc64CheckValueHex"))
        XCTAssertEqual(IrohaConnectNorito.crc64(Data()), 0)
    }

    func testNetworkID_whenTairaLiteral_thenDecodesTheWebBytes() throws {
        let taira = try IrohaConnectNetworkID.parse(Vectors.string("network", "tairaNetworkIdLiteral"))
        XCTAssertEqual(taira, .taira)
        XCTAssertEqual(taira.bytes, Vectors.bytes("network", "tairaNetworkIdHex"))
        let other = try IrohaConnectNetworkID.parse(Vectors.string("network", "otherNetworkIdLiteral"))
        XCTAssertEqual(other.bytes, Vectors.bytes("network", "otherNetworkIdHex"))
        XCTAssertEqual(IrohaConnectProfile.taira.networkPrefix, Vectors.section("network")["networkPrefix"] as? Int)
    }

    func testNetworkID_whenMalformed_thenRejects() {
        let literal = IrohaConnectNetworkID.taira.literal
        let malformed = [
            literal.lowercased(),
            literal.replacingOccurrences(of: "#6774", with: "#6775"),
            literal.replacingOccurrences(of: "hash:", with: "hush:"),
            String(literal.dropLast()),
            // An unmarked hash (last byte even) is not a NetworkId.
            "hash:" + String(repeating: "07", count: 31) + "06#" + IrohaConnectNetworkID.crc16Literal("hash:" + String(repeating: "07", count: 31) + "06")
        ]
        for value in malformed {
            XCTAssertThrowsError(try IrohaConnectNetworkID.parse(value), value)
        }
    }

    // MARK: - Links

    func testWalletURI_whenTairaInvitation_thenBindsSidAndBuildsTheRelaySocket() throws {
        let link = Vectors.section("link")
        let parsed = try IrohaConnectWalletURI.parse(Vectors.string("link", "uri"))

        XCTAssertEqual(parsed.scheme, "iroha")
        XCTAssertEqual(parsed.profile, .taira)
        XCTAssertEqual(parsed.sessionIDLiteral, link["sid"] as? String)
        XCTAssertEqual(parsed.sessionID, Vectors.bytes("link", "sidHex"))
        XCTAssertEqual(parsed.appPublicKey, Vectors.bytes("link", "appPublicKeyHex"))
        XCTAssertEqual(parsed.nonce, Vectors.bytes("link", "nonceHex"))
        XCTAssertEqual(parsed.token, link["token"] as? String)
        XCTAssertEqual(parsed.relayToken, link["relay"] as? String)
        XCTAssertEqual(parsed.webSocketURL.absoluteString, link["webSocketUrl"] as? String)
        XCTAssertEqual(parsed.webSocketSubprotocol, link["webSocketProtocol"] as? String)
        XCTAssertEqual(try IrohaConnectWalletURI.parse(Vectors.string("link", "irohaconnectUri")).scheme, "irohaconnect")
        XCTAssertEqual(
            IrohaConnectWireCodec.relayAuthHash(sessionID: parsed.sessionID, relayToken: parsed.relayToken),
            Vectors.bytes("link", "relayAuthHashHex")
        )
    }

    func testWalletURI_whenNotAnExactCurrentInvitation_thenRefusesWithTheWebCode() throws {
        let invalid = try XCTUnwrap(Vectors.section("link")["invalid"] as? [[String: Any]])
        XCTAssertEqual(invalid.count, 21)
        for entry in invalid {
            let name = entry["name"] as? String ?? ""
            let expected = entry["code"] as? String
            XCTAssertThrowsError(try IrohaConnectWalletURI.parse(entry["uri"] as? String ?? ""), name) { error in
                XCTAssertEqual((error as? IrohaConnectError)?.code, expected, name)
            }
        }
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(String(repeating: "a", count: 5000)))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(""))
    }

    func testErrors_whenShown_thenUseShortActionableText() {
        let errors: [IrohaConnectError] = [
            .invalidLink("x"), .retiredLink, .unknownNetwork, .networkUnavailable, .wrongNode, .invalidFrame("x")
        ]
        XCTAssertEqual(Set(errors.map(\.code)).count, errors.count)
        for error in errors {
            let text = error.localizedDescription
            XCTAssertFalse(text.isEmpty)
            XCTAssertLessThan(text.count, 100, text)
        }
    }

    // MARK: - Plain frames

    func testOpenFrame_whenCapturedFromLiveTaira_thenDecodesMetadataAndPermissions() throws {
        let capture = try XCTUnwrap(Vectors.section("frames")["tairaOpenCapture"] as? [String: Any])
        let sid = try XCTUnwrap(Data(base64Encoded: (capture["sid"] as? String ?? "")
                .replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "="))
        let frameBytes = try XCTUnwrap(Data(irohaConnectHex: capture["frameHex"] as? String ?? ""))

        let frame = try IrohaConnectWireCodec.decodeFrame(frameBytes, sessionID: sid)

        XCTAssertEqual(frame.direction, .appToWallet)
        XCTAssertEqual(frame.sequence, 1)
        guard case let .control(.open(open)) = frame.kind else {
            return XCTFail("expected Open")
        }
        XCTAssertEqual(open.appPublicKey.irohaConnectHex, capture["appPublicKeyHex"] as? String)
        XCTAssertEqual(open.networkID.irohaConnectHex, capture["networkIdHex"] as? String)
        XCTAssertEqual(open.appMetadata, IrohaConnectAppMetadata(name: "Fearless capture", url: "https://example.org", iconHash: nil))
        XCTAssertEqual(open.permissions, IrohaConnectPermissions(methods: ["sign_transaction", "sign_raw"], events: [], resources: nil))

        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(frameBytes, sessionID: Data(repeating: 1, count: 32))) {
            XCTAssertEqual(($0 as? IrohaConnectError)?.code, "iroha_connect_invalid_frame")
        }
        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(frameBytes.prefix(900), sessionID: sid))
        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(frameBytes + Data([0]), sessionID: sid))
        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(Data(), sessionID: sid))
    }

    func testApproval_whenBuiltForTheWebInputs_thenPreimageAndFrameMatchByteForByte() throws {
        let link = try IrohaConnectWalletURI.parse(Vectors.string("link", "uri"))
        let account = try XCTUnwrap(Vectors.section("frames")["account"] as? [String: Any])
        let accountID = try XCTUnwrap(account["accountId"] as? String)
        let walletKeyPair = try IrohaConnectWalletKeyPair(rawPrivateKey: Vectors.bytes("frames", "walletPrivateKeyHex"))
        XCTAssertEqual(walletKeyPair.publicKey, Vectors.bytes("frames", "walletPublicKeyHex"))

        let preimage = try IrohaConnectWireCodec.approvalPreimage(IrohaConnectWireCodec.ApprovalInput(
            sessionID: link.sessionID,
            networkID: link.networkID.bytes,
            appPublicKey: link.appPublicKey,
            walletPublicKey: walletKeyPair.publicKey,
            accountID: accountID,
            permissionsField: Data([0]),
            relayToken: link.relayToken
        ))
        XCTAssertEqual(preimage, Vectors.bytes("frames", "approvalPreimageWithoutPermissionsHex"))

        let signature = Vectors.bytes("frames", "approveSignatureWithoutPermissionsHex")
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: XCTUnwrap(Data(irohaConnectHex: account["publicKeyHex"] as? String ?? "")))
        XCTAssertTrue(publicKey.isValidSignature(signature, for: preimage))
        let frame = try IrohaConnectWireCodec.encodeApproveFrame(
            sessionID: link.sessionID,
            sequence: 1,
            walletPublicKey: walletKeyPair.publicKey,
            accountID: accountID,
            permissionsField: Data([0]),
            signature: signature
        )
        XCTAssertEqual(frame, Vectors.bytes("frames", "approveFrameWithoutPermissionsHex"))
        XCTAssertThrowsError(try IrohaConnectWireCodec.encodeApproveFrame(
            sessionID: link.sessionID,
            sequence: 1,
            walletPublicKey: walletKeyPair.publicKey,
            accountID: accountID,
            permissionsField: Data([7]),
            signature: signature
        ))
        XCTAssertThrowsError(try IrohaConnectWireCodec.encodeApproveFrame(
            sessionID: link.sessionID,
            sequence: 1,
            walletPublicKey: walletKeyPair.publicKey,
            accountID: accountID,
            permissionsField: Data([0]),
            signature: Data(repeating: 1, count: 63)
        ))
    }

    func testControlFrames_whenEncoded_thenMatchTheWebAndStayBinary() throws {
        let sid = Vectors.bytes("link", "sidHex")
        XCTAssertEqual(
            try IrohaConnectWireCodec.encodeRejectFrame(
                sessionID: sid,
                sequence: 2,
                code: 4001,
                codeID: "user_rejected",
                reason: "The wallet user rejected the connection."
            ),
            Vectors.bytes("frames", "rejectFrameHex")
        )
        let ping = try IrohaConnectWireCodec.encodePingFrame(sessionID: sid, sequence: 3, nonce: 0xFFFF_FFFF_FFFF_FFFE)
        XCTAssertEqual(ping, Vectors.bytes("frames", "pingFrameHex"))
        XCTAssertEqual(
            try IrohaConnectWireCodec.decodeFrame(ping, sessionID: sid),
            IrohaConnectFrame(direction: .walletToApp, sequence: 3, kind: .control(.ping(0xFFFF_FFFF_FFFF_FFFE)))
        )
        XCTAssertEqual(
            try IrohaConnectWireCodec.encodePongFrame(sessionID: sid, sequence: 4, nonce: 7),
            Vectors.bytes("frames", "pongFrameHex")
        )
        XCTAssertThrowsError(try IrohaConnectWireCodec.encodeRejectFrame(sessionID: sid, sequence: 2, code: 1, codeID: "9bad", reason: "x"))
        XCTAssertThrowsError(try IrohaConnectWireCodec.encodePingFrame(sessionID: sid, sequence: 0, nonce: 1))
    }

    // MARK: - Keys and envelopes

    func testDirectionKeys_whenDerived_thenMatchTheWebKeys() throws {
        let keys = try directionKeys()
        XCTAssertEqual(keys.appKey.withUnsafeBytes { Data($0) }, Vectors.bytes("frames", "appKeyHex"))
        XCTAssertEqual(keys.walletKey.withUnsafeBytes { Data($0) }, Vectors.bytes("frames", "walletKeyHex"))
    }

    func testEnvelopes_whenSealed_thenMatchTheWebFramesAndOnlyTheAppKeyOpensAppCiphertext() throws {
        let sid = Vectors.bytes("link", "sidHex")
        let keys = try directionKeys()
        XCTAssertEqual(
            try IrohaConnectWireCodec.sealEnvelope(keys: keys, sessionID: sid, sequence: 5, payload: .signResultOK(signature: Data(repeating: 7, count: 64))),
            Vectors.bytes("frames", "sealedSignResultOkHex")
        )
        XCTAssertEqual(
            try IrohaConnectWireCodec.sealEnvelope(
                keys: keys,
                sessionID: sid,
                sequence: 6,
                payload: .signResultError(code: "SIGNING_KEY_REQUIRED", message: "no key")
            ),
            Vectors.bytes("frames", "sealedSignResultErrHex")
        )
        let close = try IrohaConnectWireCodec.sealEnvelope(
            keys: keys,
            sessionID: sid,
            sequence: 7,
            payload: .close(code: 1000, reason: "The wallet disconnected.", retryable: false)
        )
        XCTAssertEqual(close, Vectors.bytes("frames", "sealedCloseHex"))

        let decoded = try IrohaConnectWireCodec.decodeFrame(close, sessionID: sid)
        guard case let .ciphertext(aead) = decoded.kind else {
            return XCTFail("expected ciphertext")
        }
        // The wallet opens only app ciphertext, and wallet ciphertext never authenticates under the app key.
        XCTAssertThrowsError(try IrohaConnectWireCodec.openEnvelope(
            keys: keys, sessionID: sid, sequence: 7, direction: .walletToApp, aead: aead
        ))
        XCTAssertThrowsError(try IrohaConnectWireCodec.openEnvelope(
            keys: keys, sessionID: sid, sequence: 7, direction: .appToWallet, aead: aead
        ))
    }

    // MARK: - Recorded session

    /// Replays the session the upstream app SDK held with the web wallet: every wallet frame the iOS engine
    /// produces must equal the web wallet's, given the same session key and the web's signatures.
    func testEngine_whenReplayingTheWebSession_thenEveryWalletFrameMatches() throws {
        let transcript = Vectors.transcript
        XCTAssertEqual(transcript.count, 11)
        let appFrames = transcript.filter { $0.direction == "app-to-wallet" }.map(\.frame)
        let walletFrames = transcript.filter { $0.direction == "wallet-to-app" }.map(\.frame)
        XCTAssertEqual(appFrames.count, 6)
        XCTAssertEqual(walletFrames.count, 5)
        let link = Vectors.sessionLink
        let account = Vectors.sessionAccount
        guard case let .control(.ping(webNonce)) = try IrohaConnectWireCodec.decodeFrame(walletFrames[4], sessionID: link.sessionID).kind else {
            return XCTFail("expected the web keepalive ping")
        }
        let engine = IrohaConnectProtocolEngine(link: link, pingNonce: webNonce &- 1, makeRequestID: { "request" })

        // Open
        let opened = try engine.receive(appFrames[0]) { account }
        XCTAssertTrue(opened.frames.isEmpty)
        guard case let .openRequested(open)? = opened.events.first else {
            return XCTFail("expected the Open request")
        }
        XCTAssertEqual(open.appMetadata, IrohaConnectAppMetadata(name: "Fearless vectors", url: "https://fearlesswallet.io", iconHash: nil))
        XCTAssertEqual(open.permissions?.methods, ["sign_transaction", "sign_raw"])
        XCTAssertEqual(engine.phase, .sessionApproval)

        // Approve
        let walletKeyPair = try IrohaConnectWalletKeyPair(rawPrivateKey: Vectors.bytes("session", "walletPrivateKeyHex"))
        let preimage = try engine.approvalPreimage(walletKeyPair: walletKeyPair)
        let approveSignature = Vectors.approveSignature(walletFrames[0])
        XCTAssertTrue(try Curve25519.Signing.PublicKey(rawRepresentation: account.publicKey).isValidSignature(approveSignature, for: preimage))
        XCTAssertEqual(try engine.approveSession(walletKeyPair: walletKeyPair, signature: approveSignature), walletFrames[0])
        XCTAssertEqual(engine.phase, .connected)

        // Transfer: reviewed, then signed with the web's signature over the same payload hash.
        let transfer = try engine.receive(appFrames[1]) { account }
        guard case let .signatureRequested(request)? = transfer.events.first else {
            return XCTFail("expected a transfer review")
        }
        XCTAssertEqual(request.payloadHash.irohaConnectHex, Vectors.string("session", "transferPayloadHashHex"))
        XCTAssertEqual(request.review.kind, .transfer)
        XCTAssertEqual(request.review.transfer?.quantity, "0.001")
        let webReview = try XCTUnwrap(Vectors.section("session")["transferReview"] as? [String: Any])
        IrohaConnectTransactionReviewTests.assertReview(request.review, equals: webReview)
        let transferSignature = Vectors.bytes("session", "transferSignatureHex")
        XCTAssertTrue(try Curve25519.Signing.PublicKey(rawRepresentation: account.publicKey).isValidSignature(transferSignature, for: request.payloadHash))
        XCTAssertEqual(try engine.approveRequest(request.requestID, signature: transferSignature), walletFrames[1])

        // Contract call: reviewed, then declined.
        let call = try engine.receive(appFrames[2]) { account }
        guard case let .signatureRequested(callRequest)? = call.events.first else {
            return XCTFail("expected a contract-call review")
        }
        XCTAssertEqual(callRequest.review.calls?.first?.entrypoint, "place_order")
        XCTAssertEqual(try engine.rejectRequest(callRequest.requestID), walletFrames[2])

        // Raw: refused with SIGNING_KEY_REQUIRED, nothing signed.
        let raw = try engine.receive(appFrames[3]) { account }
        XCTAssertEqual(raw.frames, [walletFrames[3]])
        XCTAssertEqual(raw.events, [.refused(code: "SIGNING_KEY_REQUIRED", notice: .rawSigningUnavailable)])

        // Keepalive ping and the app's pong.
        XCTAssertEqual(try engine.keepAlivePing(), walletFrames[4])
        XCTAssertEqual(try engine.receive(appFrames[4]) { account }, IrohaConnectProtocolEngine.Reaction())

        // The app closes the session.
        XCTAssertEqual(try engine.receive(appFrames[5]) { account }.events, [.closedByApp])
        XCTAssertEqual(engine.phase, .closed)
        XCTAssertNil(try engine.keepAlivePing())
    }

    func testEngine_whenFramesAreReplayedReorderedOrEarly_thenFailsClosed() throws {
        let appFrames = Vectors.transcript.filter { $0.direction == "app-to-wallet" }.map(\.frame)
        let account = Vectors.sessionAccount

        // Data before Open.
        XCTAssertThrowsError(try IrohaConnectProtocolEngine(link: Vectors.sessionLink).receive(appFrames[1]) { account })

        // A replayed Open.
        let replay = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        _ = try replay.receive(appFrames[0]) { account }
        XCTAssertThrowsError(try replay.receive(appFrames[0]) { account })

        // Ciphertext before the wallet approved: the frame is in sequence but there are no keys yet.
        let early = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        _ = try early.receive(appFrames[0]) { account }
        XCTAssertThrowsError(try early.receive(appFrames[1]) { account })

        // A wallet-direction frame relayed back to the wallet.
        let mirrored = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        let ping = try IrohaConnectWireCodec.encodePingFrame(sessionID: Vectors.sessionLink.sessionID, sequence: 1, nonce: 1)
        XCTAssertThrowsError(try mirrored.receive(ping) { account })

        // No usable account: the Open is not answered.
        let noAccount = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        XCTAssertThrowsError(try noAccount.receive(appFrames[0]) { throw IrohaConnectAccountProviderError.accountUnavailable })

        // Wallet decisions outside their phase.
        let idle = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        XCTAssertThrowsError(try idle.approvalPreimage(walletKeyPair: IrohaConnectWalletKeyPair()))
        XCTAssertThrowsError(try idle.rejectSession())
        XCTAssertThrowsError(try idle.approveRequest("x", signature: Data(count: 64)))
        XCTAssertNil(try idle.keepAlivePing())
        XCTAssertNil(idle.disconnect())
    }

    func testEngine_whenTheWalletEndsTheSession_thenTellsTheAppFirst() throws {
        let appFrames = Vectors.transcript.filter { $0.direction == "app-to-wallet" }.map(\.frame)
        let account = Vectors.sessionAccount

        let pendingApproval = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        _ = try pendingApproval.receive(appFrames[0]) { account }
        let cancel = try XCTUnwrap(pendingApproval.disconnect())
        guard case let .control(.reject(code, codeID, _)) = try IrohaConnectWireCodec.decodeFrame(cancel, sessionID: Vectors.sessionLink.sessionID).kind else {
            return XCTFail("expected a Reject frame")
        }
        XCTAssertEqual(code, 4001)
        XCTAssertEqual(codeID, "user_rejected")

        let connected = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        _ = try connected.receive(appFrames[0]) { account }
        let walletKeyPair = IrohaConnectWalletKeyPair()
        _ = try connected.approveSession(walletKeyPair: walletKeyPair, signature: Data(repeating: 1, count: 64))
        let close = try XCTUnwrap(connected.disconnect())
        guard case .ciphertext = try IrohaConnectWireCodec.decodeFrame(close, sessionID: Vectors.sessionLink.sessionID).kind else {
            return XCTFail("expected a sealed Close")
        }
        XCTAssertEqual(connected.phase, .closed)
        XCTAssertNil(connected.disconnect())
    }

    func testEngine_whenTheAppAsksTwiceOrWithoutPermission_thenRefusesWithoutAsking() throws {
        let appFrames = Vectors.transcript.filter { $0.direction == "app-to-wallet" }.map(\.frame)
        let account = Vectors.sessionAccount
        let engine = IrohaConnectProtocolEngine(link: Vectors.sessionLink)
        _ = try engine.receive(appFrames[0]) { account }
        let walletKeyPair = try IrohaConnectWalletKeyPair(rawPrivateKey: Vectors.bytes("session", "walletPrivateKeyHex"))
        _ = try engine.approveSession(walletKeyPair: walletKeyPair, signature: Vectors.approveSignature(Vectors.transcript[1].frame))
        _ = try engine.receive(appFrames[1]) { account }
        XCTAssertNotNil(engine.pending)

        // The app's next request arrives while the transfer is still under review.
        let second = try engine.receive(appFrames[2]) { account }
        XCTAssertEqual(second.events, [.refused(code: "REQUEST_IN_FLIGHT", notice: .requestInProgress)])
        XCTAssertEqual(second.frames.count, 1)
        XCTAssertEqual(engine.phase, .requestApproval)

        let pendingID = try XCTUnwrap(engine.pending?.requestID)
        XCTAssertThrowsError(try engine.approveRequest("other", signature: Data(count: 64)))
        let expired = try engine.expireRequest(pendingID)
        XCTAssertFalse(expired.isEmpty)
        XCTAssertNil(engine.pending)
        XCTAssertEqual(engine.phase, .connected)
    }

    private func directionKeys() throws -> IrohaConnectDirectionKeys {
        try IrohaConnectDirectionKeys(
            walletKeyPair: IrohaConnectWalletKeyPair(rawPrivateKey: Vectors.bytes("frames", "walletPrivateKeyHex")),
            appPublicKey: Vectors.bytes("link", "appPublicKeyHex"),
            sessionID: Vectors.bytes("link", "sidHex")
        )
    }
}
