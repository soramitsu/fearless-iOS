import CryptoKit
import XCTest
@testable import fearless

final class IrohaConnectProtocolTests: XCTestCase {
    private let walletURI = "irohaconnect://connect?" +
        "sid=yjnfVXnZeSYGYZRtmaP7falZC6w04-qu9eQ-9dBsDvQ&" +
        "network_id=hash%3A82531CE8EAE8BFF6BEECA4698BFD13A3BC8BEC5F0EE0D23D428C97FC17AB0F3B%233E94&" +
        "app_pk=ew1H2TQn-DERYHgcfHM_2J-IlwrvSQ2KoO4ZpMuKGxQ&" +
        "nonce=EREREREREREREREREREREQ&v=1&role=wallet&" +
        "node=https%3A%2F%2Ftaira.sora.org&" +
        "token=IiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI&" +
        "relay=REREREREREREREREREREREREREREREREREREREREREQ"

    private let accountID = "sorauﾛ1PﾗLｦK4QｼYKtﾓxbggTTCGﾗﾇﾆstKoｿﾏﾌｴgTxFｿﾀoｴ6P1FWK"
    private let accountPublicKeyHex = "c853ad0f0cd2b619aea92ceec4fd56a24d6499d584ce79257e45cfd8139b60a7"
    private let walletPublicKeyHex = "38ab664bd86f77d7e66bdd9ae0792913a94fd8b33a1260027e4b46c1f4884c67"

    private let openFrameHex = "2000000000000000ca39df5579d979260661946d99a3fb7da9590bac34e3eaaef5e43ef5d06c0ef4" +
        "040000000000000000000000080000000000000001000000000000006b01000000000000000000005f010000000000000000000053010000" +
        "0000000020000000000000007b0d47d93427f8311160781c7c733fd89f88970aef490d8aa0ee19a4cb8a1b145300000000000000014a0000" +
        "00000000000e0000000000000006000000000000005572616e61692300000000000000011a00000000000000120000000000000068747470" +
        "733a2f2f7572616e61692e6170700100000000000000002800000000000000200000000000000082531ce8eae8bff6beeca4698bfd13a3bc" +
        "8bec5f0ee0d23d428c97fc17ab0f3b9800000000000000018f00000000000000200000000000000001000000000000001000000000000000" +
        "08000000000000007369676e5f726177080000000000000000000000000000004f0000000000000001460000000000000001000000000000" +
        "0036000000000000002e000000000000007572616e61692e69726f6861636f6e6e6563742e636f6e74726163742d63616c6c2d7369676e61" +
        "747572652e7631"

    private let openFrameWithoutMetadataHex = "2000000000000000ca39df5579d979260661946d99a3fb7da9590bac34e3eaaef5e43ef5d06c0ef4" +
        "040000000000000000000000080000000000000001000000000000001901000000000000000000000d010000000000000000000001010000" +
        "0000000020000000000000007b0d47d93427f8311160781c7c733fd89f88970aef490d8aa0ee19a4cb8a1b14010000000000000000280000" +
        "0000000000200000000000000082531ce8eae8bff6beeca4698bfd13a3bc8bec5f0ee0d23d428c97fc17ab0f3b9800000000000000018f00" +
        "00000000000020000000000000000100000000000000100000000000000008000000000000007369676e5f72617708000000000000000000" +
        "0000000000004f00000000000000014600000000000000010000000000000036000000000000002e000000000000007572616e61692e6972" +
        "6f6861636f6e6e6563742e636f6e74726163742d63616c6c2d7369676e61747572652e7631"

    private let approvalPreimageHex = "0600646f6d61696e180000000000000069726f68612d636f6e6e6563747c617070726f76657c76310a006e6574776f726b5f696420000000" +
        "0000000082531ce8eae8bff6beeca4698bfd13a3bc8bec5f0ee0d23d428c97fc17ab0f3b0b00636f6e73747261696e74732000000000000000" +
        "a1d0a18c07c30f1f79c91ee56bd6cabae829d21387f790b23a1e9f1558b8f92003007369642000000000000000ca39df5579d97926066194" +
        "6d99a3fb7da9590bac34e3eaaef5e43ef5d06c0ef406006170705f706b20000000000000007b0d47d93427f8311160781c7c733fd89f88970" +
        "aef490d8aa0ee19a4cb8a1b14090077616c6c65745f706b200000000000000038ab664bd86f77d7e66bdd9ae0792913a94fd8b33a1260027e" +
        "4b46c1f4884c670a006163636f756e745f69645200000000000000736f726175efbe9b3150efbe974cefbda64b3451efbdbc594b74efbe9378" +
        "62676754544347efbe97efbe87efbe8673744b6fefbdbfefbe8fefbe8cefbdb467547846efbdbfefbe806fefbdb436503146574b0b00706572" +
        "6d697373696f6e73200000000000000032f3bc7bbdfd6c4a5a8200bcc8fa710a5523a85fba3dbda0be474700082508990a0072656c61795f" +
        "617574682000000000000000e6f97ee7e2c32bc90f84e79b40867dfb96f4745723bbd124e85b82c9bd9f62a0"

    private let approvalSignatureHex = "2b111ba84b18fcd86119ea02ff3e26e361397eae42e9a4fea1016d58e299a598" +
        "4c051379a43f0bec70e91b42c2ef60a269ff926ec2ac4e8db7f956d62313c50b"

    private let approvalFrameHex = "2000000000000000ca39df5579d979260661946d99a3fb7da9590bac34e3eaaef5e43ef5d06c0ef404000000000000000100000008000000" +
        "000000000100000000000000ac0100000000000000000000a001000000000000010000009401000000000000200000000000000038ab664bd8" +
        "6f77d7e66bdd9ae0792913a94fd8b33a1260027e4b46c1f4884c675a000000000000005200000000000000736f726175efbe9b3150efbe974c" +
        "efbda64b3451efbdbc594b74efbe937862676754544347efbe97efbe87efbe8673744b6fefbdbfefbe8fefbe8cefbdb467547846efbdbfefbe" +
        "806fefbdb436503146574b9800000000000000018f000000000000002000000000000000010000000000000010000000000000000800000000" +
        "0000007369676e5f726177080000000000000000000000000000004f0000000000000001460000000000000001000000000000003600000000" +
        "0000002e000000000000007572616e61692e69726f6861636f6e6e6563742e636f6e74726163742d63616c6c2d7369676e61747572652e7631" +
        "0100000000000000005900000000000000010000000000000000480000000000000040000000000000002b111ba84b18fcd86119ea02ff3e26" +
        "e361397eae42e9a4fea1016d58e299a5984c051379a43f0bec70e91b42c2ef60a269ff926ec2ac4e8db7f956d62313c50b"

    private let requestFrameHex = "2000000000000000ca39df5579d979260661946d99a3fb7da9590bac34e3eaaef5e43ef5d06c0ef404000000000000000000000008000000" +
        "000000000200000000000000e80000000000000001000000dc00000000000000040000000000000000000000c800000000000000c000000000" +
        "0000000c0c6543a570ee132be8503fc1e55d65f79cf362b72820ab727449171f2d40e5a51e13cdec09e4b9f4e5399970b7dc1afc591f1bb96" +
        "fce33f1d49d8ed7cd6ea713cde7882807223eb26efc7500fceac6f7611c7fad7e02fdf7397e1c689845b4f7afe98420ef39fb04245a2c6e14" +
        "cfd3365ba7c0ed8afecb6647670d32fa7555bcb7f30a40a2395df1b23827e6c2bf8359536771176a7c0d2a45da55d01ec8e8da957379d52c" +
        "597cb95e8de97e44a62cd126ca735e8a166954bdeb32d8854ec3"

    private let signSignatureHex = "4f31e7fdbcc88d6d0d66243c39c22c57e4050b87976f376d07257784cec348f9" +
        "6a6fdbfbea9276e04df2035ea28272b17397205b9182338d1abc3f9f7e2ca508"

    private let resultFrameHex = "2000000000000000ca39df5579d979260661946d99a3fb7da9590bac34e3eaaef5e43ef5d06c0ef404000000000000000100000008000000" +
        "000000000200000000000000dd0000000000000001000000d100000000000000040000000000000001000000bd00000000000000b500000000" +
        "000000eeac6cc6af21125d24981ab91bb74afa5818e8222bb6bd120e7c81fa0c15f113887b9a6a745294243ee9385387ca305bc9aa2010f4d8" +
        "db2bbe22044f0cba69425b046602a8cfb90e9d07e2b7cd94f58bdd6711776c948bcbef4dcd03ce82f65f21be3eac915bcb77a371fd13fc208d" +
        "86afadbc560c377e169c7aec0940f5102191d79c04ca6374edf8557607923052c71d87bd71aecc415a7dcdf5767d3ce82f8e6378d4360ab189" +
        "a5b01019d79683832135324713"

    private let pingFrameHex = "2000000000000000ca39df5579d979260661946d99a3fb7da9590bac34e3eaaef5e43ef5d06c0ef404000000000000000000000008000000" +
        "0000000002000000000000002800000000000000000000001c0000000000000004000000100000000000000008000000000000000807060504" +
        "030201"

    private let pongFrameHex = "2000000000000000ca39df5579d979260661946d99a3fb7da9590bac34e3eaaef5e43ef5d06c0ef404000000000000000100000008000000" +
        "0000000002000000000000002800000000000000000000001c0000000000000005000000100000000000000008000000000000000807060504" +
        "030201"

    func testNetworkID_whenCanonicalTaira_thenDecodesExactBytes() throws {
        let networkID = try IrohaConnectNetworkID.parse(IrohaConnectNetworkID.tairaLiteral)

        XCTAssertEqual(networkID, .taira)
        XCTAssertEqual(networkID.bytes.count, 32)
        XCTAssertEqual(networkID.bytes.last, 0x3B)
    }

    func testNetworkID_whenMalformed_thenRejects() {
        XCTAssertThrowsError(try IrohaConnectNetworkID.parse(IrohaConnectNetworkID.tairaLiteral.lowercased()))
        XCTAssertThrowsError(try IrohaConnectNetworkID.parse(IrohaConnectNetworkID.tairaLiteral.replacingOccurrences(of: "3E94", with: "3E95")))
        XCTAssertThrowsError(try IrohaConnectNetworkID.parse("hash:" + String(repeating: "0", count: 64) + "#0000"))
    }

    func testErrors_whenPresentedToUser_thenUseActionableSafeDescriptions() {
        XCTAssertEqual(
            IrohaConnectError.invalidPermissions.errorDescription,
            "This dApp requested an IrohaConnect capability that Fearless does not allow."
        )
        XCTAssertEqual(
            IrohaConnectError.authenticationFailed.errorDescription,
            "Secure IrohaConnect verification failed. Create a fresh pairing request and try again."
        )
        XCTAssertFalse(IrohaConnectError.invalidSequence.localizedDescription.contains("invalidSequence"))
    }

    func testWalletURI_whenCanonicalUranaiHandoff_thenValidatesBindingAndTransport() throws {
        let handoff = try IrohaConnectWalletURI.parse(walletURI)

        XCTAssertEqual(handoff.networkID, .taira)
        XCTAssertEqual(handoff.nodeURL.absoluteString, "https://taira.sora.org")
        XCTAssertEqual(handoff.webSocketURL.absoluteString, "wss://taira.sora.org/v1/connect/ws?sid=yjnfVXnZeSYGYZRtmaP7falZC6w04-qu9eQ-9dBsDvQ&role=wallet")
        XCTAssertEqual(handoff.webSocketSubprotocol, "iroha-connect.token.v1.SWlJaUlpSWlJaUlpSWlJaUlpSWlJaUlpSWlJaUlpSWlJaUlpSWlJaUlpSQ")
        XCTAssertEqual(handoff.appPublicKey.hex, "7b0d47d93427f8311160781c7c733fd89f88970aef490d8aa0ee19a4cb8a1b14")
        XCTAssertEqual(try IrohaConnectWalletURI.parse(walletURI.replacingOccurrences(of: "irohaconnect:", with: "iroha:")).sessionID, handoff.sessionID)
    }

    func testWalletURI_whenIdentityOrShapeIsSubstituted_thenRejects() {
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(walletURI + "&sid=x"))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(walletURI + "&unknown=x"))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(walletURI.replacingOccurrences(of: "&relay=", with: "&missing=")))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(walletURI.replacingOccurrences(of: "role=wallet", with: "role=app")))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(walletURI.replacingOccurrences(of: "taira.sora.org", with: "evil.example")))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(walletURI.replacingOccurrences(of: "sid=y", with: "sid=x")))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(walletURI + "="))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse(walletURI.replacingOccurrences(
            of: "hash%3A82531CE8EAE8BFF6BEECA4698BFD13A3BC8BEC5F0EE0D23D428C97FC17AB0F3B%233E94",
            with: "hash%3A0000000000000000000000000000000000000000000000000000000000000001%23C50E"
        )))
        XCTAssertThrowsError(try IrohaConnectWalletURI.parse("irohaconnect://connect/path?" + walletURI.components(separatedBy: "?")[1]))
    }

    func testWireCodec_whenUranaiOpenArrives_thenDecodesMetadataAndScopedPermission() throws {
        let frame = try IrohaConnectWireCodec.decodeFrame(try XCTUnwrap(Data(hex: openFrameHex)))
        guard case let .control(.open(open)) = frame.kind else {
            return XCTFail("Expected Open control")
        }

        XCTAssertEqual(frame.direction, .appToWallet)
        XCTAssertEqual(frame.sequence, 1)
        XCTAssertEqual(open.appMetadata?.name, "Uranai")
        XCTAssertEqual(open.appMetadata?.url?.absoluteString, "https://uranai.app")
        XCTAssertNil(open.appMetadata?.iconHash)
        XCTAssertEqual(open.permissions, .uranaiContractSigning)
        XCTAssertEqual(open.networkID, IrohaConnectNetworkID.taira.bytes)
    }

    func testWireCodec_whenOpenOmitsMetadata_thenExposesNilFallback() throws {
        let frame = try IrohaConnectWireCodec.decodeFrame(
            try XCTUnwrap(Data(hex: openFrameWithoutMetadataHex))
        )
        guard case let .control(.open(open)) = frame.kind else {
            return XCTFail("Expected Open control")
        }
        XCTAssertNil(open.appMetadata)
    }

    func testWireCodec_whenFrameIsMalformedOrOversized_thenRejects() throws {
        let valid = try XCTUnwrap(Data(hex: openFrameHex))
        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(valid + Data([0])))

        var invalidDirection = valid
        invalidDirection[48] = 2
        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(invalidDirection))

        var zeroSequence = valid
        zeroSequence[60] = 0
        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(zeroSequence))
        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(
            Data(repeating: 0, count: IrohaConnectWireCodec.maximumFrameSize + 1)
        ))

        let insecureMetadata = openFrameHex.replacingOccurrences(of: "6874747073", with: "6874747078")
        XCTAssertThrowsError(try IrohaConnectWireCodec.decodeFrame(
            try XCTUnwrap(Data(hex: insecureMetadata))
        ))
    }

    func testProtocolEngine_whenCanonicalUranaiExchange_thenMatchesJavaScriptVectors() throws {
        let handoff = try IrohaConnectWalletURI.parse(walletURI)
        let engine = try IrohaConnectProtocolEngine(
            handoff: handoff,
            ephemeralPrivateKey: Data(repeating: 0x55, count: 32)
        )
        XCTAssertEqual(engine.walletEphemeralPublicKey.hex, walletPublicKeyHex)

        let open = try engine.acceptOpenFrame(try XCTUnwrap(Data(hex: openFrameHex)))
        XCTAssertEqual(open.appMetadata?.name, "Uranai")

        let accountPublicKey = try XCTUnwrap(Data(hex: accountPublicKeyHex))
        let preimage = try engine.makeApprovalPreimage(
            accountID: accountID,
            signingPublicKey: accountPublicKey
        )
        XCTAssertEqual(preimage.hex, approvalPreimageHex)

        // CryptoKit intentionally randomizes Ed25519 signatures. Consume the
        // deterministic Noble/JS signature to exercise byte-for-byte interop.
        let accountPublicKeyVerifier = try Curve25519.Signing.PublicKey(
            rawRepresentation: accountPublicKey
        )
        let approvalSignature = try XCTUnwrap(Data(hex: approvalSignatureHex))
        XCTAssertTrue(accountPublicKeyVerifier.isValidSignature(approvalSignature, for: preimage))
        let approvalFrame = try engine.makeApprovalFrame(
            accountID: accountID,
            signingPublicKey: accountPublicKey,
            signature: approvalSignature
        )
        XCTAssertEqual(approvalFrame.hex, approvalFrameHex)

        let request = try engine.decryptSignRawRequest(
            try XCTUnwrap(Data(hex: requestFrameHex))
        )
        XCTAssertEqual(request.domain, IrohaConnectPermissions.contractCallSignatureDomain)
        XCTAssertEqual(String(data: request.message, encoding: .utf8), "canonical Uranai contract call")

        let signature = try XCTUnwrap(Data(hex: signSignatureHex))
        XCTAssertTrue(accountPublicKeyVerifier.isValidSignature(signature, for: request.message))
        let result = try engine.makeSignResultFrame(signature: signature)
        XCTAssertEqual(result.hex, resultFrameHex)
    }

    func testProtocolEngine_whenPermissionOrSessionIsSubstituted_thenFailsClosed() throws {
        let handoff = try IrohaConnectWalletURI.parse(walletURI)
        let wrongPermissionFrame = openFrameHex.replacingOccurrences(of: "7369676e5f726177", with: "7369676e5f726176")
        let permissionEngine = try IrohaConnectProtocolEngine(
            handoff: handoff,
            ephemeralPrivateKey: Data(repeating: 0x55, count: 32)
        )
        XCTAssertThrowsError(try permissionEngine.acceptOpenFrame(
            try XCTUnwrap(Data(hex: wrongPermissionFrame))
        )) { error in
            XCTAssertEqual(error as? IrohaConnectError, .invalidPermissions)
        }

        var wrongSession = try XCTUnwrap(Data(hex: openFrameHex))
        wrongSession[8] ^= 1
        let sessionEngine = try IrohaConnectProtocolEngine(
            handoff: handoff,
            ephemeralPrivateKey: Data(repeating: 0x55, count: 32)
        )
        XCTAssertThrowsError(try sessionEngine.acceptOpenFrame(wrongSession)) { error in
            XCTAssertEqual(error as? IrohaConnectError, .sessionIDMismatch)
        }
    }

    func testProtocolEngine_whenCiphertextOrSignatureIsTampered_thenFailsClosed() throws {
        let engine = try approvedEngine()
        var tamperedRequest = try XCTUnwrap(Data(hex: requestFrameHex))
        tamperedRequest[tamperedRequest.index(before: tamperedRequest.endIndex)] ^= 1
        XCTAssertThrowsError(try engine.decryptSignRawRequest(tamperedRequest)) { error in
            XCTAssertEqual(error as? IrohaConnectError, .authenticationFailed)
        }

        let signatureEngine = try approvedEngine()
        let request = try signatureEngine.decryptSignRawRequest(
            try XCTUnwrap(Data(hex: requestFrameHex))
        )
        let invalidSignature = Data(repeating: 0, count: 64)
        XCTAssertFalse(request.message.isEmpty)
        XCTAssertThrowsError(try signatureEngine.makeSignResultFrame(signature: invalidSignature)) { error in
            XCTAssertEqual(error as? IrohaConnectError, .invalidSignature)
        }
    }

    func testProtocolEngine_whenPingArrives_thenReturnsSequencedPong() throws {
        let engine = try approvedEngine()
        let pong = try engine.makePongFrame(for: try XCTUnwrap(Data(hex: pingFrameHex)))

        XCTAssertEqual(pong.hex, pongFrameHex)
        let decoded = try IrohaConnectWireCodec.decodeFrame(pong)
        XCTAssertEqual(decoded.direction, .walletToApp)
        XCTAssertEqual(decoded.sequence, 2)
        XCTAssertEqual(decoded.kind, .control(.pong(0x0102_0304_0506_0708)))
        XCTAssertThrowsError(try engine.makePongFrame(for: try XCTUnwrap(Data(hex: pingFrameHex))))
    }

    func testProtocolEngine_whenCallsAreOutOfOrder_thenRejectsStateAndReplay() throws {
        let handoff = try IrohaConnectWalletURI.parse(walletURI)
        let engine = try IrohaConnectProtocolEngine(
            handoff: handoff,
            ephemeralPrivateKey: Data(repeating: 0x55, count: 32)
        )
        XCTAssertThrowsError(try engine.decryptSignRawRequest(
            try XCTUnwrap(Data(hex: requestFrameHex))
        ))
        _ = try engine.acceptOpenFrame(try XCTUnwrap(Data(hex: openFrameHex)))
        XCTAssertThrowsError(try engine.acceptOpenFrame(try XCTUnwrap(Data(hex: openFrameHex))))
        XCTAssertThrowsError(try engine.makeApprovalFrame(
            accountID: accountID,
            signingPublicKey: try XCTUnwrap(Data(hex: accountPublicKeyHex)),
            signature: Data(repeating: 0, count: 64)
        ))
    }

    private func approvedEngine() throws -> IrohaConnectProtocolEngine {
        let engine = try IrohaConnectProtocolEngine(
            handoff: IrohaConnectWalletURI.parse(walletURI),
            ephemeralPrivateKey: Data(repeating: 0x55, count: 32)
        )
        _ = try engine.acceptOpenFrame(try XCTUnwrap(Data(hex: openFrameHex)))
        let accountPublicKey = try XCTUnwrap(Data(hex: accountPublicKeyHex))
        let preimage = try engine.makeApprovalPreimage(
            accountID: accountID,
            signingPublicKey: accountPublicKey
        )
        let accountKey = try Curve25519.Signing.PrivateKey(
            rawRepresentation: Data(repeating: 0x77, count: 32)
        )
        _ = try engine.makeApprovalFrame(
            accountID: accountID,
            signingPublicKey: accountPublicKey,
            signature: try accountKey.signature(for: preimage)
        )
        return engine
    }
}

private extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else {
            return nil
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
