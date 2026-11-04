import Foundation
import IrohaCrypto
import SSFModels
import XCTest

final class SECSignerTests: XCTestCase {
    /// RFC 6979 with low S, computed independently with @noble/curves 1.9.7. The key is
    /// SHA-256("fearless secp256k1 signer vector key"), the message SHA-256("fearless secp256k1
    /// signer vector message"); the signature is r, s and the recovery id.
    private let privateKey = "546896b446419a1781b8de05e61f72a45524e8527a3704f52d674d604c9f1f6f"
    private let publicKey = "025571fe2486e678d1be66aba49756c43c4c31227ba8fa4625730522301a85a815"
    private let message = "07bb685c9d4a37c4b62d6228b9716a537a3b53879a153e7f5443e66d32b2fe8d"
    private let signature =
        "b372b0a0913f1a0dd445c347ccc6914182cc421ea9184e49b303c8c6af0f623034a17f214a0f8894ec934f2faf5e00b35f75530c8a79868f7f120a0476ae00e900"

    func testSignsTheReferenceVector() throws {
        let key = try SECPrivateKey(rawData: hex(privateKey))
        let signed = try SECSigner(privateKey: key).sign(hex(message))

        XCTAssertEqual(signed.rawData(), try hex(signature))
    }

    func testSignatureRecoversTheSignerPublicKey() throws {
        let keypair = try SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: hex(privateKey)))
        let signed = try SECSigner(privateKey: keypair.privateKey()).sign(hex(message))
        let recovered = try SECSignatureVerifier().recover(fromSignature: signed, forOriginalData: hex(message))

        XCTAssertEqual(keypair.publicKey().rawData(), try hex(publicKey))
        XCTAssertEqual(recovered.rawData(), keypair.publicKey().rawData())
    }

    private func hex(_ string: String) throws -> Data {
        try Data(hexStringSSF: string)
    }
}
