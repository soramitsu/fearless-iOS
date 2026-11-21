import CryptoKit
import XCTest
@testable import FearlessWalletConnect

final class CryptoTests: XCTestCase {
    func testSessionKeyComesFromX25519HKDFAndTheTopicFromSHA256() throws {
        // RFC 7748 section 6.1 keys.
        let alice = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: XCTUnwrap(Hex.decode("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"))
        )
        let bobPublic = try XCTUnwrap(Hex.decode("de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f"))

        let symKey = try WalletConnectCrypto.deriveSymmetricKey(privateKey: alice, peerPublicKey: bobPublic)

        XCTAssertEqual(Hex.encode(symKey), "ea1d8a20f476d1e1ec952ca42708b8f7161ce7c81eadf97e520e2b40333decd5")
        XCTAssertEqual(
            WalletConnectCrypto.topic(forSymmetricKey: symKey),
            "1ca1d70db64cab0f93de5934e27f7114e8e9fd7dd3c7145d81ce7f2dd2cd05c8"
        )
    }

    func testBothPeersDeriveTheSameKey() throws {
        let one = Curve25519.KeyAgreement.PrivateKey()
        let two = Curve25519.KeyAgreement.PrivateKey()

        XCTAssertEqual(
            try WalletConnectCrypto.deriveSymmetricKey(privateKey: one, peerPublicKey: two.publicKey.rawRepresentation),
            try WalletConnectCrypto.deriveSymmetricKey(privateKey: two, peerPublicKey: one.publicKey.rawRepresentation)
        )
    }

    func testPeerKeyThatGivesTheAllZeroSecretIsRefused() {
        XCTAssertThrowsError(
            try WalletConnectCrypto.deriveSymmetricKey(
                privateKey: Curve25519.KeyAgreement.PrivateKey(),
                peerPublicKey: Data(repeating: 0, count: 32)
            )
        )
        XCTAssertThrowsError(
            try WalletConnectCrypto.deriveSymmetricKey(
                privateKey: Curve25519.KeyAgreement.PrivateKey(),
                peerPublicKey: Data(repeating: 1, count: 31)
            )
        )
    }

    func testType0EnvelopeOpensWithItsKeyOnlyAndRefusesAChangedByte() throws {
        let key = try WalletConnectCrypto.randomKey()
        let message = #"{"id":1,"jsonrpc":"2.0","method":"wc_sessionPing","params":{"text":"ü😀"}}"#
        let sealed = try WalletConnectCrypto.seal(Data(message.utf8), symmetricKey: key)
        let envelope = try WalletConnectCrypto.decodeEnvelope(sealed)

        XCTAssertEqual(envelope.type, 0)
        XCTAssertEqual(envelope.nonce.count, 12)
        XCTAssertEqual(String(decoding: try WalletConnectCrypto.open(sealed, symmetricKey: key), as: UTF8.self), message)

        // Padding is optional on the way in.
        var unpadded = sealed
        while unpadded.hasSuffix("=") {
            unpadded.removeLast()
        }
        XCTAssertEqual(try WalletConnectCrypto.open(unpadded, symmetricKey: key), Data(message.utf8))

        var bytes = try XCTUnwrap(Data(base64Encoded: sealed))
        bytes[bytes.count - 1] ^= 1
        XCTAssertThrowsError(try WalletConnectCrypto.open(bytes.base64EncodedString(), symmetricKey: key)) {
            XCTAssertEqual($0 as? WalletConnectCryptoError, .authenticationFailed)
        }
        XCTAssertThrowsError(try WalletConnectCrypto.open(sealed, symmetricKey: try WalletConnectCrypto.randomKey()))
    }

    func testEnvelopeLayoutWithAKnownNonce() throws {
        let key = Data(repeating: 0x42, count: 32)
        let nonce = Data((0 ..< 12).map(UInt8.init))
        let sealed = try WalletConnectCrypto.seal(Data("{}".utf8), symmetricKey: key, nonce: nonce)
        let bytes = try XCTUnwrap(Data(base64Encoded: sealed))

        XCTAssertEqual(bytes.first, 0)
        XCTAssertEqual(bytes.dropFirst().prefix(12), nonce)
        XCTAssertEqual(bytes.count, 1 + 12 + 2 + 16)

        // The same as CryptoKit's own ChaCha20-Poly1305 with no associated data.
        let box = try ChaChaPoly.seal(Data("{}".utf8), using: SymmetricKey(data: key), nonce: ChaChaPoly.Nonce(data: nonce))
        XCTAssertEqual(bytes.dropFirst(), box.combined)
    }

    func testType1EnvelopeIsReadButNeverOpenedAndType2IsRefused() throws {
        let sender = Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
        let body = Data([1]) + sender + Data(repeating: 9, count: 12) + Data(repeating: 3, count: 20)
        let encoded = body.base64EncodedString()

        let envelope = try WalletConnectCrypto.decodeEnvelope(encoded)
        XCTAssertEqual(envelope.type, 1)
        XCTAssertEqual(envelope.senderPublicKey, sender)
        XCTAssertThrowsError(try WalletConnectCrypto.open(encoded, symmetricKey: Data(repeating: 1, count: 32))) {
            XCTAssertEqual($0 as? WalletConnectCryptoError, .unexpectedEnvelopeType(1))
        }
        XCTAssertThrowsError(try WalletConnectCrypto.decodeEnvelope(Data([2, 123, 125]).base64EncodedString())) {
            XCTAssertEqual($0 as? WalletConnectCryptoError, .unsupportedEnvelopeType(2))
        }
        XCTAssertThrowsError(try WalletConnectCrypto.decodeEnvelope("not base64!"))
        XCTAssertThrowsError(try WalletConnectCrypto.decodeEnvelope(Data([0, 1, 2]).base64EncodedString()))
    }

    func testRelaySignInTokenMatchesWalletConnectRelayAuth() throws {
        let seed = Data((0 ..< 32).map { UInt8(($0 * 7) & 0xFF) })
        let token = try RelayAuth.token(
            seed: seed,
            audience: "wss://relay.walletconnect.org",
            subject: "sub",
            issuedAt: 1_700_000_000
        )
        // WalletConnect's relay-auth gives these bytes for the same inputs (the web wallet's vector).
        let expected = "eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9."
            + "eyJpc3MiOiJkaWQ6a2V5Ono2TWtqZTRWaHFxM0g3WU1vR3RhWERvaDgxS1JlV0ZQdnR3RW1RZkt1UEIyR2d4SyIsInN1YiI6InN1YiIs"
            + "ImF1ZCI6IndzczovL3JlbGF5LndhbGxldGNvbm5lY3Qub3JnIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjE3MDAwODY0MDB9."
            + "yGZUUoefzFXr5vwwmvgu5oE3g76YIYVWxAP8S8tRbajD0PcnlNhho_aveRlFxl6RX2taLIT71zdXXBWXtqsLCw"
        let parts = token.split(separator: ".").map(String.init)
        let expectedParts = expected.split(separator: ".").map(String.init)

        XCTAssertEqual(parts[0], expectedParts[0])
        XCTAssertEqual(parts[1], expectedParts[1])
        XCTAssertEqual(try RelayAuth.clientId(seed: seed), "did:key:z6Mkje4Vhqq3H7YMoGtaXDoh81KReWFPvtwEmQfKuPB2GgxK")

        // CryptoKit may randomize Ed25519 signatures; each one still verifies, and so does relay-auth's.
        let publicKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed).publicKey
        let signingInput = Data("\(parts[0]).\(parts[1])".utf8)
        XCTAssertTrue(publicKey.isValidSignature(try XCTUnwrap(Base64.decodeURL(parts[2])), for: signingInput))
        XCTAssertTrue(publicKey.isValidSignature(try XCTUnwrap(Base64.decodeURL(expectedParts[2])), for: signingInput))

        let claims = try XCTUnwrap(RelayAuth.payload(ofToken: token))
        XCTAssertEqual(claims["exp"]?.int64Value, 1_700_086_400)
    }

    func testMessageHashIsTheSHA256OfTheMessageAsSent() {
        XCTAssertEqual(
            WalletConnectCrypto.messageHash(#"{"id":1,"jsonrpc":"2.0","result":true}"#),
            "1b6640c68d669b4cdafb0b92e29e90b58c66d8aaf01c3781e5577706f67a1536"
        )
    }

    func testBase58AndBase64URL() throws {
        let samples: [Data] = [Data(), Data([0]), Data([0, 0, 1]), Data((0 ..< 34).map { UInt8($0 * 13 & 0xFF) })]
        for sample in samples {
            XCTAssertEqual(Base58.decode(Base58.encode(sample)), sample)
            XCTAssertEqual(Base64.decodeURL(Base64.encodeURL(sample)), sample)
        }
        XCTAssertEqual(Base58.encode(Data("hello world".utf8)), "StV1DL6CwTryKyV")
        XCTAssertNil(Base58.decode("0OIl"))
        XCTAssertNil(Base64.decode("abc*"))
        XCTAssertNil(Base64.decode("a"))
    }
}
