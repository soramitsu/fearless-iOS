import Foundation
import XCTest
@testable import SSFUtils

final class KeystoreExtractorFramingTests: XCTestCase {
    private let header = Data(repeating: 0, count: 32) + Data([2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])

    func testRejectsEveryTruncatedScryptNonceAndAuthenticationTag() throws {
        let completeFrame = header + Data(repeating: 0, count: 24 + 16)
        for length in 0 ..< completeFrame.count {
            let definition = definition(
                encoded: Data(completeFrame.prefix(length)),
                encrypted: true
            )
            XCTAssertThrowsError(try KeystoreExtractor().extractFromDefinition(
                definition,
                password: "1"
            )) { error in
                guard case KeystoreExtractorError.invalidDataLength = error else {
                    return XCTFail("Expected a framing error for \(length) bytes, got \(error)")
                }
            }
        }
    }

    func testCompleteFrameWithInvalidAuthenticationStillFailsAsDecryption() throws {
        let definition = definition(
            encoded: header + Data(repeating: 0, count: 24 + 16),
            encrypted: true
        )
        XCTAssertThrowsError(try KeystoreExtractor().extractFromDefinition(
            definition,
            password: "1"
        )) { error in
            if case KeystoreExtractorError.invalidDataLength = error {
                XCTFail("A complete frame must reach authentication, not the truncation guard")
            }
        }
    }

    func testUnencryptedPkcs8DoesNotRequireEncryptedFraming() throws {
        let secret = Data(repeating: 0x11, count: 32)
        let publicKey = Data(repeating: 0x22, count: 32)
        let prefix = KeystoreConstants.pkcs8Header + secret + KeystoreConstants.pkcs8Divider
        let encoded = prefix + publicKey
        let restored = try KeystoreExtractor().extractFromDefinition(
            definition(encoded: encoded, encrypted: false), password: nil
        )
        XCTAssertEqual(restored.secretKeyData, secret)
        XCTAssertEqual(restored.publicKeyData, publicKey)
        for length in 0 ..< prefix.count {
            XCTAssertThrowsError(try KeystoreExtractor().extractFromDefinition(
                definition(encoded: Data(encoded.prefix(length)), encrypted: false), password: nil
            ))
        }
    }

    func testValidEncryptedKeystoreRoundTrip() throws {
        let original = KeystoreData(
            address: nil,
            secretKeyData: Data(repeating: 0x11, count: 32),
            publicKeyData: Data(repeating: 0x22, count: 32),
            cryptoType: .ed25519
        )
        let definition = try KeystoreBuilder().build(
            from: original,
            password: "correct",
            isEthereum: false
        )
        let restored = try KeystoreExtractor().extractFromDefinition(
            definition,
            password: "correct"
        )
        XCTAssertEqual(restored.secretKeyData, original.secretKeyData)
        XCTAssertEqual(restored.publicKeyData, original.publicKeyData)
        XCTAssertThrowsError(try KeystoreExtractor().extractFromDefinition(
            definition,
            password: "wrong"
        ))
    }

    private func definition(encoded: Data, encrypted: Bool) -> KeystoreDefinition {
        KeystoreDefinition(
            address: nil,
            encoded: encoded.base64EncodedString(),
            encoding: KeystoreEncoding(
                content: ["pkcs8", "ed25519"],
                type: encrypted ? ["scrypt", "xsalsa20-poly1305"] : [],
                version: "3"
            ),
            meta: nil
        )
    }
}
