import XCTest
@testable import fearless
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCrypto
import SSFUtils

/// IK-13: sr25519 known answers for the native library the release signs with.
///
/// The fixture `UpgradeFixtures/Crypto/sr25519-known-answers.v1.json` is written by
/// `scripts/deps/sr25519-provenance/cross-check-slices.py`. Its stored keys and "shipped"
/// signatures come from the device slice of `sr25519lib.xcframework` that App Store 4.0.4
/// shipped, so the keychain rows built here are byte-for-byte what 4.0.4 wrote (64-byte
/// scalar || nonce under the `-substrateSecretKey` tag, including the random nonce of a soft
/// junction). Expected public keys and addresses are the root golden catalog
/// (GW-M1, GW-M4, GW-M5, GW-S1, GW-J1), checked against @scure/sr25519 and a from-spec
/// implementation when the fixture was written.
///
/// Every signature the app makes here is verified by `Sr25519SpecVerifier`, which shares no
/// code with the native library, as well as by the app's own `SNSignatureVerifier`.
///
/// These tests use no simulator-only API: run them on a device with
/// `xcodebuild test -scheme fearless.tests -destination 'platform=iOS,id=<udid>'
/// -only-testing:fearlessTests/Sr25519KnownAnswerTests`.
final class Sr25519KnownAnswerTests: XCTestCase {
    private static let fixture: Sr25519KnownAnswers? = {
        guard let url = Bundle(for: Sr25519KnownAnswerTests.self).url(
            forResource: "sr25519-known-answers.v1",
            withExtension: "json",
            subdirectory: "UpgradeFixtures/Crypto"
        ), let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(Sr25519KnownAnswers.self, from: data)
    }()

    private var fixture: Sr25519KnownAnswers!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try XCTUnwrap(Self.fixture, "sr25519 known-answer fixture is missing from the test bundle")
        XCTAssertEqual(fixture.format, "fearless.ios.sr25519-known-answers")
        XCTAssertEqual(fixture.version, 1)
        XCTAssertEqual(fixture.signingContext, "substrate")
    }

    // MARK: - The independent verifier

    func testSpecVerifierConstantsMatchTheirDefinitions() {
        XCTAssertTrue(Sr25519SpecVerifier.curveConstantsHold)
        // RFC 9496 A.1: the encoding of the ristretto255 generator.
        XCTAssertEqual(
            Sr25519SpecVerifier.encodedBasePoint,
            try? Data(knownAnswerHex: "e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76")
        )
    }

    // MARK: - Key material 4.0.4 stored

    /// Public keys from root `config/upgrade-matrix/golden-wallets.v1.json` (the soft-path JSON
    /// is the export of GW-M5 `/0`), repeated here so a regenerated fixture cannot drift from the
    /// catalog unnoticed.
    private static let goldenPublicKeys = [
        "GW-M1/root": "66933bd1f37070ef87bd1198af3dacceb095237f803f3d32b173e6b425ed7972",
        "GW-M4/hard-password": "42553f1a8a44bd93a8412a09320f8c85b14c124ce3b8a82dcbabf4a866cc731d",
        "GW-M5/hard-soft": "c2cb78846562cdbf41fcd022f38316e050829010e4805a2658b8e0a59eb3312b",
        "GW-M5/soft": "0c4f096369eaeea12066045a810c9e5ea73b81d420c1b606324050ec477ab676",
        "GW-S1/raw-seed": "d43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d",
        "GW-J1/sr25519": "66933bd1f37070ef87bd1198af3dacceb095237f803f3d32b173e6b425ed7972",
        "GW-J1/sr25519-soft": "0c4f096369eaeea12066045a810c9e5ea73b81d420c1b606324050ec477ab676"
    ]

    func testStoredKeysWrittenBy404ProveTheirGoldenIdentity() throws {
        let golden = Set(fixture.wallets.map(\.id) + fixture.keystores.map(\.id))
            .intersection(Self.goldenPublicKeys.keys)
        XCTAssertEqual(golden, Set(Self.goldenPublicKeys.keys), "fixture lost a golden wallet")

        for wallet in fixture.wallets {
            let stored = try wallet.stored.keys()
            XCTAssertEqual(stored.secret.count, 64, wallet.id)
            XCTAssertEqual(
                stored.publicKey,
                try Data(knownAnswerHex: XCTUnwrap(Self.goldenPublicKeys[wallet.id])),
                "\(wallet.id): not the golden public key"
            )
            XCTAssertEqual(
                Sr25519SpecVerifier.publicKey(fromSecret: stored.secret), stored.publicKey,
                "\(wallet.id): stored secret does not prove its public key"
            )
            let accountId = try stored.publicKey.publicKeyToAccountId()
            for (prefix, address) in wallet.ss58 {
                let format = try ChainFormat.substrate(XCTUnwrap(UInt16(prefix)))
                XCTAssertEqual(try AddressFactory.address(for: accountId, chainFormat: format), address, wallet.id)
            }
        }
        for keystore in fixture.keystores {
            guard let stored = try keystore.stored?.keys() else { continue }
            XCTAssertEqual(Sr25519SpecVerifier.publicKey(fromSecret: stored.secret), stored.publicKey, keystore.id)
            if let golden = Self.goldenPublicKeys[keystore.id] {
                XCTAssertEqual(stored.publicKey, try Data(knownAnswerHex: golden), keystore.id)
            }
        }
    }

    func testCheckedSignerSignsWithEveryKeyShapedAs404WroteIt() throws {
        var stored = try fixture.wallets.map { try ($0.id, $0.stored.keys()) }
        stored += try fixture.keystores.compactMap { keystore in
            try keystore.stored.map { try (keystore.id, $0.keys()) }
        }
        XCTAssertTrue(stored.contains { $0.0 == "GW-M5/soft" }, "soft-path key missing from the fixture")

        for (id, keys) in stored {
            for isChainAccount in [false, true] {
                let (signer, keychain, tag) = try makeSigner(for: keys, isChainAccount: isChainAccount)
                for (name, message) in try fixture.decodedMessages() {
                    let signature = try signer.sign(message).rawData()
                    XCTAssertTrue(
                        Sr25519SpecVerifier.verify(signature: signature, message: message, publicKey: keys.publicKey),
                        "\(id) \(name): the independent verifier rejects the app's signature"
                    )
                    XCTAssertTrue(try nativeVerify(signature, message, keys.publicKey), "\(id) \(name)")
                    XCTAssertFalse(
                        Sr25519SpecVerifier.verify(
                            signature: signature, message: message + Data([0]), publicKey: keys.publicKey
                        ),
                        "\(id) \(name): signature also verifies for another message"
                    )
                }
                XCTAssertEqual(try keychain.fetchKey(for: tag), keys.secret, "\(id): signing changed the stored key")
            }
        }
    }

    func testSignaturesMadeBy404AndByReferenceVerify() throws {
        let messages = try fixture.decodedMessages()
        for wallet in fixture.wallets {
            let publicKey = try wallet.stored.keys().publicKey
            XCTAssertEqual(Set(wallet.signatures.map(\.writer)), ["shipped", "reference"], wallet.id)
            for entry in wallet.signatures {
                let message = try XCTUnwrap(messages[entry.message])
                let signature = try Data(knownAnswerHex: entry.signature)
                let label = "\(wallet.id) \(entry.message) by \(entry.writer)"
                XCTAssertTrue(
                    Sr25519SpecVerifier.verify(signature: signature, message: message, publicKey: publicKey), label
                )
                XCTAssertTrue(try nativeVerify(signature, message, publicKey), label)

                var tampered = signature
                tampered[5] ^= 0x01
                XCTAssertFalse(
                    Sr25519SpecVerifier.verify(signature: tampered, message: message, publicKey: publicKey), label
                )
                XCTAssertFalse(try nativeVerify(tampered, message, publicKey), label)
                XCTAssertFalse(try nativeVerify(signature, message + Data([0]), publicKey), label)
            }
        }
    }

    func testCheckedSignerRefusesInvalidKeysAndKeepsThem() throws {
        XCTAssertEqual(Set(fixture.refused.map(\.id)), ["mismatched-keypair", "non-canonical-secret", "invalid-public"])
        for entry in fixture.refused {
            let keys = try StoredKeys(
                secret: Data(knownAnswerHex: entry.substrateSecretKey),
                publicKey: Data(knownAnswerHex: entry.substratePublicKey)
            )
            let (signer, keychain, tag) = try makeSigner(for: keys, isChainAccount: false)
            XCTAssertThrowsError(try signer.sign(Data("transfer".utf8)), entry.id) { error in
                let nsError = error as NSError
                XCTAssertEqual(nsError.domain, "SNSigner", entry.id)
                XCTAssertEqual(nsError.code, entry.signerError, entry.id)
            }
            XCTAssertEqual(try keychain.fetchKey(for: tag), keys.secret, "\(entry.id): refused key was changed")
        }
    }

    // MARK: - Derivation through the import code

    func testMnemonicAndSeedImportDeriveWhat404Stored() throws {
        for wallet in fixture.wallets {
            let expected = try wallet.stored.keys()
            let keychain = InMemoryKeychain()
            let model = try importWallet(wallet, keychain: keychain)
            XCTAssertEqual(model.substratePublicKey, expected.publicKey, wallet.id)
            XCTAssertEqual(model.substrateCryptoType, CryptoType.sr25519.rawValue, wallet.id)

            let secret = try keychain.fetchKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(model.metaId))
            XCTAssertEqual(secret.prefix(32), expected.secret.prefix(32), "\(wallet.id): secret scalar differs")
            if wallet.nonceDeterministic {
                XCTAssertEqual(secret, expected.secret, "\(wallet.id): 4.0.4 stored a different keypair")
            }
            XCTAssertEqual(Sr25519SpecVerifier.publicKey(fromSecret: secret), expected.publicKey, wallet.id)

            let derivationTag = KeystoreTagV2.substrateDerivationTagForMetaId(model.metaId)
            if wallet.derivationPath.isEmpty {
                XCTAssertFalse(try keychain.checkKey(for: derivationTag), wallet.id)
            } else {
                XCTAssertEqual(try keychain.fetchKey(for: derivationTag), Data(wallet.derivationPath.utf8), wallet.id)
            }

            let message = Data("import \(wallet.id)".utf8)
            let response = substrateResponse(publicKey: expected.publicKey, metaId: model.metaId, isChainAccount: false)
            let signature = try SigningWrapper(keystore: keychain, metaId: model.metaId, accountResponse: response)
                .sign(message).rawData()
            XCTAssertTrue(
                Sr25519SpecVerifier.verify(signature: signature, message: message, publicKey: expected.publicKey),
                wallet.id
            )
        }
    }

    /// A soft junction draws a fresh nonce on every derivation (schnorrkel 0.9.1
    /// `derived_key_simple`), so the same phrase and path never reproduce the nonce 4.0.4
    /// stored. Identity checks must compare the public key and the scalar, never the nonce.
    func testSoftJunctionNonceIsFreshButIdentityIsStable() throws {
        let wallet = try XCTUnwrap(fixture.wallets.first { $0.id == "GW-M5/soft" })
        XCTAssertFalse(wallet.nonceDeterministic)
        let stored = try wallet.stored.keys()
        let chaincodes = try SubstrateJunctionFactory().parse(path: wallet.derivationPath).chaincodes
        let seed = try Data(knownAnswerHex: wallet.miniSecret)

        let first = try SR25519KeypairFactory().createKeypairFromSeed(seed, chaincodeList: chaincodes)
        let second = try SR25519KeypairFactory().createKeypairFromSeed(seed, chaincodeList: chaincodes)
        for keypair in [first, second] {
            XCTAssertEqual(keypair.publicKey().rawData(), stored.publicKey)
            XCTAssertEqual(keypair.privateKey().rawData().prefix(32), stored.secret.prefix(32))
            XCTAssertNotEqual(keypair.privateKey().rawData().suffix(32), stored.secret.suffix(32))
        }
        XCTAssertNotEqual(first.privateKey().rawData().suffix(32), second.privateKey().rawData().suffix(32))
    }

    func testDerivationVectorsMatchProductionParity() throws {
        XCTAssertEqual(fixture.derivations.count, 40)
        for vector in fixture.derivations {
            let label = "\(vector.seed.prefix(8)) \(vector.path)"
            let chaincodes = vector.path.isEmpty ? [] :
                try SubstrateJunctionFactory().parse(path: vector.path).chaincodes
            let keypair = try SR25519KeypairFactory().createKeypairFromSeed(
                Data(knownAnswerHex: vector.seed),
                chaincodeList: chaincodes
            )
            let secret = keypair.privateKey().rawData()
            XCTAssertEqual(secret.prefix(32), try Data(knownAnswerHex: vector.secretScalar), label)
            XCTAssertEqual(keypair.publicKey().rawData(), try Data(knownAnswerHex: vector.publicKey), label)
            if let nonce = vector.nonce {
                XCTAssertEqual(secret.suffix(32), try Data(knownAnswerHex: nonce), label)
            }
        }
    }

    // MARK: - polkadot-js JSON

    func testPolkadotJsJsonImportsAsStoredAndRoundTrips() throws {
        let importable = fixture.keystores.filter { $0.stored != nil }
        XCTAssertTrue(importable.contains { $0.id == "GW-J1/sr25519" })
        XCTAssertTrue(importable.contains { $0.id == "GW-J1/sr25519-soft" })

        for keystore in importable {
            let expected = try XCTUnwrap(keystore.stored).keys()
            let keychain = InMemoryKeychain()
            let model = try importKeystore(keystore, keychain: keychain)
            XCTAssertEqual(model.substratePublicKey, expected.publicKey, keystore.id)
            let tag = KeystoreTagV2.substrateSecretKeyTagForMetaId(model.metaId)
            XCTAssertEqual(try keychain.fetchKey(for: tag), expected.secret, "\(keystore.id): imported key differs")

            let response = substrateResponse(publicKey: expected.publicKey, metaId: model.metaId, isChainAccount: false)
            let message = Data("json \(keystore.id)".utf8)
            let signature = try SigningWrapper(keystore: keychain, metaId: model.metaId, accountResponse: response)
                .sign(message).rawData()
            XCTAssertTrue(
                Sr25519SpecVerifier.verify(signature: signature, message: message, publicKey: expected.publicKey),
                keystore.id
            )

            let address = try AddressFactory.address(
                for: expected.publicKey.publicKeyToAccountId(), chainFormat: .substrate(42)
            )
            let exported = try KeystoreExportWrapper(keystore: keychain).export(
                chainAccount: response,
                password: "IK-13 export pässwörd",
                address: address,
                metaId: model.metaId,
                accountId: nil,
                genesisHash: nil
            )
            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: exported)
            XCTAssertEqual(definition.encoding.content, ["pkcs8", "sr25519"], keystore.id)
            XCTAssertEqual(definition.encoding.type, ["scrypt", "xsalsa20-poly1305"], keystore.id)
            XCTAssertEqual(definition.encoding.version, "3", keystore.id)
            XCTAssertEqual(definition.address, address, keystore.id)

            let reimported = try KeystoreExtractor().extractFromDefinition(definition, password: "IK-13 export pässwörd")
            XCTAssertEqual(reimported.secretKeyData, expected.secret, "\(keystore.id): export round trip changed the key")
            XCTAssertEqual(reimported.publicKeyData, expected.publicKey, keystore.id)
        }
    }

    func testLegacyUnscryptedJsonIsRejectedWithoutWritingAKey() throws {
        let legacy = fixture.keystores.filter { $0.rejected == true }
        XCTAssertEqual(legacy.map(\.id), ["android-parity/polkadotjs-sr25519-legacy"])
        for keystore in legacy {
            let keychain = InMemoryKeychain()
            XCTAssertThrowsError(try importKeystore(keystore, keychain: keychain), keystore.id)
        }
    }

    // MARK: - Helpers

    private func makeSigner(
        for keys: StoredKeys,
        isChainAccount: Bool
    ) throws -> (SigningWrapper, InMemoryKeychain, String) {
        let keychain = InMemoryKeychain()
        let metaId = UUID().uuidString
        let response = substrateResponse(publicKey: keys.publicKey, metaId: metaId, isChainAccount: isChainAccount)
        let tag = KeystoreTagV2.substrateSecretKeyTagForMetaId(
            metaId,
            accountId: isChainAccount ? response.accountId : nil
        )
        try keychain.saveKey(keys.secret, with: tag)
        return (SigningWrapper(keystore: keychain, metaId: metaId, accountResponse: response), keychain, tag)
    }

    private func substrateResponse(publicKey: Data, metaId: String, isChainAccount: Bool) -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
            accountId: (try? publicKey.publicKeyToAccountId()) ?? publicKey,
            publicKey: publicKey,
            name: "IK-13",
            cryptoType: .sr25519,
            addressPrefix: 0,
            isEthereumBased: false,
            isChainAccount: isChainAccount,
            walletId: metaId
        )
    }

    private func nativeVerify(_ signature: Data, _ message: Data, _ publicKey: Data) throws -> Bool {
        try SNSignatureVerifier().verify(
            SNSignature(rawData: signature),
            forOriginalData: message,
            using: SNPublicKey(rawData: publicKey)
        )
    }

    private func importWallet(_ wallet: Sr25519KnownAnswers.Wallet, keychain: KeystoreProtocol) throws
        -> MetaAccountModel {
        let factory = MetaAccountOperationFactory(keystore: keychain)
        let operation: BaseOperation<MetaAccountModel>
        switch wallet.importKind {
        case "mnemonic":
            let request = try MetaAccountImportMnemonicRequest(
                mnemonic: IRMnemonicCreator().mnemonic(fromList: XCTUnwrap(wallet.mnemonic)),
                username: wallet.id,
                substrateDerivationPath: wallet.derivationPath,
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .sr25519,
                defaultChainId: nil
            )
            operation = factory.newMetaAccountOperation(request: request, isBackuped: true)
        case "seed":
            let request = try MetaAccountImportSeedRequest(
                substrateSeed: XCTUnwrap(wallet.seed),
                ethereumSeed: nil,
                username: wallet.id,
                substrateDerivationPath: wallet.derivationPath,
                ethereumDerivationPath: nil,
                cryptoType: .sr25519
            )
            operation = factory.newMetaAccountOperation(request: request, isBackuped: true)
        default:
            throw Sr25519KnownAnswers.Failure.unknownImport(wallet.importKind)
        }
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let model = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(model, settings: settings,
            importOperation: operation as? PersistenceBoundKeychainOperation)
        return model
    }

    private func importKeystore(_ keystore: Sr25519KnownAnswers.Keystore, keychain: KeystoreProtocol) throws
        -> MetaAccountModel {
        let request = MetaAccountImportKeystoreRequest(
            substrateKeystore: keystore.json,
            ethereumKeystore: nil,
            substratePassword: keystore.password,
            ethereumPassword: nil,
            username: keystore.id,
            cryptoType: .sr25519
        )
        let operation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request, isBackuped: true)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let model = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(model, settings: settings,
            importOperation: operation as? PersistenceBoundKeychainOperation)
        return model
    }
}

// MARK: - Fixture

private struct StoredKeys {
    let secret: Data
    let publicKey: Data
}

private struct Sr25519KnownAnswers: Decodable {
    enum Failure: Error {
        case unknownImport(String)
        case invalidHex(String)
    }

    struct Stored: Decodable {
        let substrateSecretKey: String
        let substratePublicKey: String

        func keys() throws -> StoredKeys {
            try StoredKeys(
                secret: Data(knownAnswerHex: substrateSecretKey),
                publicKey: Data(knownAnswerHex: substratePublicKey)
            )
        }
    }

    struct Signature: Decodable {
        let message: String
        let writer: String
        let signature: String
    }

    struct Wallet: Decodable {
        let id: String
        let importKind: String
        let mnemonic: String?
        let seed: String?
        let derivationPath: String
        let miniSecret: String
        let nonceDeterministic: Bool
        let stored: Stored
        let ss58: [String: String]
        let signatures: [Signature]

        enum CodingKeys: String, CodingKey {
            case id, mnemonic, seed, derivationPath, miniSecret, nonceDeterministic, stored, ss58, signatures
            case importKind = "import"
        }
    }

    struct Refused: Decodable {
        let id: String
        let signerError: Int
        let substrateSecretKey: String
        let substratePublicKey: String
    }

    struct Derivation: Decodable {
        let seed: String
        let path: String
        let secretScalar: String
        let nonce: String?
        let publicKey: String
    }

    struct Keystore: Decodable {
        let id: String
        let password: String
        let json: String
        let stored: Stored?
        let rejected: Bool?
    }

    let format: String
    let version: Int
    let signingContext: String
    let messages: [String: String]
    let wallets: [Wallet]
    let refused: [Refused]
    let derivations: [Derivation]
    let keystores: [Keystore]

    func decodedMessages() throws -> [String: Data] {
        try messages.mapValues { try Data(knownAnswerHex: $0) }
    }
}

private extension Data {
    init(knownAnswerHex hex: String) throws {
        let digits = Array(hex.hasPrefix("0x") ? hex.dropFirst(2) : Substring(hex))
        guard digits.count % 2 == 0 else { throw Sr25519KnownAnswers.Failure.invalidHex(hex) }
        var bytes = [UInt8]()
        bytes.reserveCapacity(digits.count / 2)
        for index in stride(from: 0, to: digits.count, by: 2) {
            guard let byte = UInt8(String(digits[index ... index + 1]), radix: 16) else {
                throw Sr25519KnownAnswers.Failure.invalidHex(hex)
            }
            bytes.append(byte)
        }
        self.init(bytes)
    }
}
