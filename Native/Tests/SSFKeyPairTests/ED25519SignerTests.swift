import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels
import XCTest

final class ED25519SignerTests: XCTestCase {
    private struct Vector {
        let seed: String
        let publicKey: String
        let message: String
        let signature: String
    }

    /// RFC 8032 section 7.1: TEST 1, TEST 2, TEST 3 and TEST SHA(abc).
    /// TEST 1024 runs in scripts/test-ed25519-blake2-native.py.
    private let rfc8032Vectors = [
        Vector(
            seed: "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60",
            publicKey: "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
            message: "",
            signature: "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
        ),
        Vector(
            seed: "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb",
            publicKey: "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c",
            message: "72",
            signature: "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
        ),
        Vector(
            seed: "c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7",
            publicKey: "fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025",
            message: "af82",
            signature: "6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a"
        ),
        Vector(
            seed: "833fe62409237b9d62ec77587520911e9a759cec1d19755b7da901b96dca3d42",
            publicKey: "ec172b93ad5e563bf4932c70e1245034c35467ef2efd4d64ebf819683467e2bf",
            message: "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
            signature: "dc2a4459e7369633a52b1bf277839a00201009a3efbf3ecb69bea2186c26b58909351fc9ac90b3ecfdfbc7c66431e0303dca179c138ac17ad9bef1177331a704"
        ),
    ]

    /// Substrate //Alice (ed25519): the seed hard-derived from the development phrase.
    private let aliceSeed = "abf8e5bdbe30c65656c0a3cbd181ff8a56294a69dfedd27982aace4a76909115"
    private let alicePublicKey = "88dc3417d5058ec4b4503e0c12ea1a0a89be200fe98922423d4334014fa6b0ee"

    func testRFC8032VectorsThroughEDSigner() throws {
        for vector in rfc8032Vectors {
            let keypair = try EDKeyFactory().derive(fromSeed: hex(vector.seed))
            let message = try hex(vector.message)
            let signature = try EDSigner(privateKey: keypair.privateKey()).sign(message)

            XCTAssertEqual(signature.rawData(), try hex(vector.signature))
            XCTAssertTrue(EDSignatureVerifier().verify(
                signature,
                forOriginalData: message,
                usingPublicKey: keypair.publicKey()
            ))
        }
    }

    /// The wallet signs with the private key Ed25519KeypairFactory derives from the stored seed.
    func testRFC8032VectorsThroughWalletKeypairFactory() throws {
        for vector in rfc8032Vectors {
            let keypair = try Ed25519KeypairFactory().createKeypairFromSeed(
                hex(vector.seed).miniSeed,
                chaincodeList: []
            )
            let signer = EDSigner(privateKey: keypair.privateKey())

            XCTAssertEqual(keypair.publicKey().rawData(), try hex(vector.publicKey))
            XCTAssertEqual(
                try signer.sign(hex(vector.message)).rawData(),
                try hex(vector.signature)
            )
        }
    }

    func testEDKeyFactoryPublicKeysAreUnchanged() throws {
        let seeds = rfc8032Vectors.map(\.seed) + [aliceSeed]
        let publicKeys = rfc8032Vectors.map(\.publicKey) + [alicePublicKey]

        for (seed, publicKey) in zip(seeds, publicKeys) {
            let keypair = try EDKeyFactory().derive(fromSeed: hex(seed))
            let fromPrivateKey = try EDKeyFactory().derive(fromPrivateKey: keypair.privateKey())

            XCTAssertEqual(keypair.publicKey().rawData(), try hex(publicKey))
            XCTAssertEqual(keypair.privateKey().rawData().count, 32)
            XCTAssertEqual(fromPrivateKey.publicKey().rawData(), try hex(publicKey))
        }
    }

    func testSigningIsDeterministic() throws {
        let keypair = try EDKeyFactory().derive(fromSeed: Data(repeating: 0x32, count: 32))
        let signer = EDSigner(privateKey: keypair.privateKey())
        let message = Data("Ed25519 signer".utf8)

        XCTAssertEqual(try signer.sign(message).rawData(), try signer.sign(message).rawData())
        XCTAssertNotEqual(try signer.sign(message).rawData(), try signer.sign(Data()).rawData())
    }

    /// A key created from its 32-byte scalar has no seed, so its nonce prefix is derived from
    /// the scalar: deterministic, but different from the RFC 8032 signature of the seed's key.
    func testScalarOnlyKeySignsDeterministically() throws {
        let scalar = "307c83864f2833cb427a2ef1c00a013cfdff2768d980c0a3a520f006904de94f"
        let expected = "0fa87eb2da834a03694aaf7a2d921d29c94a06fe73e73081cbf08aa2844e998ccc82b962e9ae1930aa21886757a7d1218fff5b79de179a1ecbc2719cd9d4490a"
        let privateKey = try EDPrivateKey(rawData: hex(scalar))
        let publicKey = try EDKeyFactory().derive(fromPrivateKey: privateKey).publicKey()
        let message = Data("IrohaCrypto EDSigner".utf8)
        let signature = try EDSigner(privateKey: privateKey).sign(message)

        XCTAssertEqual(publicKey.rawData(), try hex(rfc8032Vectors[0].publicKey))
        XCTAssertEqual(signature.rawData(), try hex(expected))
        XCTAssertTrue(EDSignatureVerifier().verify(
            signature,
            forOriginalData: message,
            usingPublicKey: publicKey
        ))
    }

    func testPrivateKeyOfWrongLengthReturnsError() throws {
        let invalidRawData = Int(IRCryptoKeyError.invalidRawData.rawValue)

        for length in [0, 31, 33, 64] {
            let privateKey = try ForeignPrivateKey(rawData: Data(repeating: 1, count: length))
            let signer = EDSigner(privateKey: privateKey)

            XCTAssertThrowsError(try signer.sign(Data("Ed25519 signer".utf8))) { error in
                XCTAssertEqual((error as NSError).domain, "EDPrivateKey")
                XCTAssertEqual((error as NSError).code, invalidRawData)
            }
        }
    }

    func testKeyFactoryRejectsWrongSeedLengths() {
        for length in [0, 1, 31, 33, 64] {
            XCTAssertThrowsError(try EDKeyFactory().derive(fromSeed: Data(
                repeating: 1,
                count: length
            ))) { error in
                XCTAssertEqual((error as NSError).domain, "EDKeyFactory")
                XCTAssertEqual(
                    (error as NSError).code,
                    Int(IRCryptoKeyError.invalidRawData.rawValue)
                )
            }
        }
    }

    func testKeyFactoryRejectsWrongScalarLengths() throws {
        for length in [0, 1, 31, 33, 64] {
            let privateKey = try ForeignPrivateKey(rawData: Data(repeating: 1, count: length))
            XCTAssertThrowsError(try EDKeyFactory().derive(fromPrivateKey: privateKey)) { error in
                XCTAssertEqual((error as NSError).domain, "EDKeyFactory")
                XCTAssertEqual(
                    (error as NSError).code,
                    Int(IRCryptoKeyError.invalidRawData.rawValue)
                )
            }
        }
    }

    private func hex(_ string: String) throws -> Data {
        try Data(hexStringSSF: string)
    }
}

private final class ForeignPrivateKey: NSObject, IRPrivateKeyProtocol {
    private let data: Data

    init(rawData data: Data) throws {
        self.data = data
        super.init()
    }

    func rawData() -> Data {
        data
    }
}
