import CryptoKit
import XCTest
@testable import FearlessWalletConnect

/// A differential check against vectors the WalletConnect SDK computed (`scripts/walletconnect/reference-vectors.mjs`,
/// with the SDK installed outside this repository). Skipped unless `FEARLESS_WC_VECTORS` names the vector file.
final class ReferenceVectorTests: XCTestCase {
    func testKeysTopicsEnvelopesHashesAndSignInsMatchTheReferenceSDK() throws {
        guard let path = ProcessInfo.processInfo.environment["FEARLESS_WC_VECTORS"] else {
            throw XCTSkip("Set FEARLESS_WC_VECTORS to a vector file from reference-vectors.mjs")
        }
        let file = try JSONParser.parse(Data(contentsOf: URL(fileURLWithPath: path)), maxBytes: 64 * 1024 * 1024)
        let cases = try XCTUnwrap(file["cases"]?.arrayValue)
        XCTAssertFalse(cases.isEmpty)
        var checks = 0

        for (index, entry) in cases.enumerated() {
            func string(_ key: String) throws -> String {
                try XCTUnwrap(entry[key]?.stringValue, "\(index) \(key)")
            }

            let privateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: XCTUnwrap(Hex.decode(string("privateKey"))))
            XCTAssertEqual(Hex.encode(privateKey.publicKey.rawRepresentation), try string("publicKey"), "\(index)")
            let symKey = try WalletConnectCrypto.deriveSymmetricKey(
                privateKey: privateKey,
                peerPublicKey: XCTUnwrap(Hex.decode(string("peerPublicKey")))
            )
            XCTAssertEqual(Hex.encode(symKey), try string("symKey"), "\(index) symKey")
            XCTAssertEqual(WalletConnectCrypto.topic(forSymmetricKey: symKey), try string("topic"), "\(index) topic")

            let message = try string("message")
            XCTAssertEqual(WalletConnectCrypto.messageHash(message), try string("messageHash"), "\(index) hash")
            let sealed = try WalletConnectCrypto.seal(Data(message.utf8), symmetricKey: symKey, nonce: XCTUnwrap(Hex.decode(string("iv"))))
            XCTAssertEqual(sealed, try string("sealed"), "\(index) envelope")
            XCTAssertEqual(String(decoding: try WalletConnectCrypto.open(string("sealed"), symmetricKey: symKey), as: UTF8.self), message)

            let seed = try XCTUnwrap(Hex.decode(string("seed")))
            XCTAssertEqual(try RelayAuth.clientId(seed: seed), try string("did"), "\(index) did")
            let issuedAt = try XCTUnwrap(entry["issuedAt"]?.int64Value)
            let token = try RelayAuth.token(seed: seed, audience: string("audience"), subject: string("subject"), issuedAt: issuedAt)
            let reference = try string("jwt").split(separator: ".").map(String.init)
            let ours = token.split(separator: ".").map(String.init)
            XCTAssertEqual(ours[0], reference[0], "\(index) jwt header")
            XCTAssertEqual(ours[1], reference[1], "\(index) jwt payload")
            let publicKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed).publicKey
            let input = Data("\(reference[0]).\(reference[1])".utf8)
            XCTAssertTrue(publicKey.isValidSignature(try XCTUnwrap(Base64.decodeURL(ours[2])), for: input), "\(index) our signature")
            XCTAssertTrue(publicKey.isValidSignature(try XCTUnwrap(Base64.decodeURL(reference[2])), for: input), "\(index) reference signature")
            checks += 11
        }

        print("Reference vectors: \(cases.count) cases, \(checks) checks against \(file["reference"]?.stringValue ?? "?")")
    }
}
