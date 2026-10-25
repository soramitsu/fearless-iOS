import Foundation
import IrohaCrypto
import XCTest

final class SR25519SignerTests: XCTestCase {
    private let message = Data("SR25519 signer boundary".utf8)

    func testValidWalletKeySignsAndVerifies() throws {
        let keypair = try SNKeyFactory().createKeypair(fromSeed: Data((0 ..< 32).map(UInt8.init)))
        let signature = try SNSigner(keypair: keypair).sign(message)

        XCTAssertEqual(signature.rawData().count, 64)
        XCTAssertTrue(SNSignatureVerifier().verify(
            signature,
            forOriginalData: message,
            using: keypair.publicKey()
        ))
    }

    func testMalformedSecretReturnsErrorWithoutAborting() throws {
        let keypair = try SNKeyFactory().createKeypair(fromSeed: Data((0 ..< 32).map(UInt8.init)))
        let invalidSecret = try SNPrivateKey(rawData: Data(repeating: 0xff, count: 64))
        let signer = SNSigner(keypair: SNKeypair(
            privateKey: invalidSecret,
            publicKey: keypair.publicKey()
        ))

        XCTAssertThrowsError(try signer.sign(message)) { error in
            XCTAssertEqual((error as NSError).domain, "SNSigner")
            XCTAssertEqual((error as NSError).code, 2)
        }
    }

    func testMalformedPublicReturnsErrorWithoutAborting() throws {
        let keypair = try SNKeyFactory().createKeypair(fromSeed: Data((0 ..< 32).map(UInt8.init)))
        let invalidPublic = try SNPublicKey(rawData: Data(repeating: 0xff, count: 32))
        let signer = SNSigner(keypair: SNKeypair(
            privateKey: keypair.privateKey(),
            publicKey: invalidPublic
        ))

        XCTAssertThrowsError(try signer.sign(message)) { error in
            XCTAssertEqual((error as NSError).domain, "SNSigner")
            XCTAssertEqual((error as NSError).code, 3)
        }
    }
}
