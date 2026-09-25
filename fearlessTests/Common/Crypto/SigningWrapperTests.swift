import XCTest
@testable import fearless
import IrohaCrypto
import SoraKeystore

class SigningWrapperTests: XCTestCase {
    static let name: String = "myname"
    static let message: String = "this is a message"
    static let substrateSeed: String = "18691a833f2c7f8c8738519ad04ac8e1ce16fc160c738ce36708defbd841e23c"
    static let ethereumSeed: String = "0xe0fa453f7646c45cbeecac10d4f48eb90868ec15d91cf0a46d9cf974f7862edf"

    private static var testSettings: SelectedWalletSettings {
        SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
    }

    func testSr25519CreationFromMnemonicAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keychain,
            settings: settings
        )

        try performSr25519SigningTest(keychain: keychain, settings: settings)
    }

    func testSr25519CreationFromSeedAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings

        try AccountCreationHelper.createMetaAccountFromSeed(substrateSeed: Self.substrateSeed,
                                                            ethereumSeed: nil,
                                                            cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)


        try performSr25519SigningTest(keychain: keychain, settings: settings)
    }

    func testSr25519CreationFromKeystoreAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings
        
        let bundle = Bundle(for: type(of: self))
        let substratePath = bundle.path(forResource: Constants.validSrKeystoreName, ofType: "json")!
        let substrateData = try Data(contentsOf: URL(fileURLWithPath: substratePath))
        
        try AccountCreationHelper.createMetaAccountFromKeystoreData(
            substrateData: substrateData,
            ethereumData: nil,
            substratePassword: Constants.validSrKeystorePassword,
            ethereumPassword: nil,
            keychain: keychain,
            settings: settings,
            cryptoType: .sr25519
        )

        try performSr25519SigningTest(keychain: keychain, settings: settings)
    }

    func testEd25519CreationFromMnemonicAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .ed25519,
            keychain: keychain,
            settings: settings
        )

        try performEd25519SigningTest(keychain: keychain, settings: settings)
    }

    func testEd25519CreationFromSeedAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings
        
        try AccountCreationHelper.createMetaAccountFromSeed(substrateSeed: Self.substrateSeed,
                                                            ethereumSeed: nil,
                                                            cryptoType: .ed25519,
                                                            keychain: keychain,
                                                            settings: settings)

        try performEd25519SigningTest(keychain: keychain, settings: settings)
    }

    func testEd25519CreationFromKeystoreAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings
        
        let bundle = Bundle(for: type(of: self))
        let substratePath = bundle.path(forResource: Constants.validEd25519KeystoreName, ofType: "json")!
        let substrateData = try Data(contentsOf: URL(fileURLWithPath: substratePath))

        try AccountCreationHelper.createMetaAccountFromKeystoreData(
            substrateData: substrateData,
            ethereumData: nil,
            substratePassword: Constants.validEd25519KeystorePassword,
            ethereumPassword: nil,
            keychain: keychain,
            settings: settings,
            cryptoType: .ed25519
        )

        try performEd25519SigningTest(keychain: keychain, settings: settings)
    }

    func testEcdsaCreationFromMnemonicAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings

        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .ecdsa,
            keychain: keychain,
            settings: settings
        )

        try performSubstrateEcdsaSigningTest(keychain: keychain, settings: settings)
        try performEthereumEcdsaSigningTest(keychain: keychain, settings: settings)
    }

    func testEcdsaCreationFromSeedAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings

        try AccountCreationHelper.createMetaAccountFromSeed(substrateSeed: Self.substrateSeed,
                                                            ethereumSeed: Self.ethereumSeed,
                                                            cryptoType: .ecdsa,
                                                            keychain: keychain,
                                                            settings: settings)

        try performSubstrateEcdsaSigningTest(keychain: keychain, settings: settings)
        try performEthereumEcdsaSigningTest(keychain: keychain, settings: settings)
    }

    func testEcdsaCreationFromKeystoreAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings

        
        let bundle = Bundle(for: type(of: self))
        let substratePath = bundle.path(forResource: Constants.validEcdsaKeystoreName, ofType: "json")!
        let ethereumPath = bundle.path(forResource: Constants.validEthereumKeystoreName, ofType: "json")!
        let substrateData = try Data(contentsOf: URL(fileURLWithPath: substratePath))
        let ethereumData = try Data(contentsOf: URL(fileURLWithPath: ethereumPath))

        try AccountCreationHelper.createMetaAccountFromKeystoreData(
            substrateData: substrateData,
            ethereumData: ethereumData,
            substratePassword: Constants.validEcdsaKeystorePassword,
            ethereumPassword: Constants.validEthereumKeystorePassword,
            keychain: keychain,
            settings: settings,
            cryptoType: .ecdsa
        )

        try performSubstrateEcdsaSigningTest(keychain: keychain, settings: settings)
        try performEthereumEcdsaSigningTest(keychain: keychain, settings: settings)
    }

    // MARK: Private

    private func performSr25519SigningTest(keychain: KeystoreProtocol,
                                           settings: SelectedWalletSettings) throws {
        let originalData = Self.message.data(using: .utf8)!

        let metaAccount = try XCTUnwrap(settings.value)

        guard let accountResponse = makeChainAccountResponse(
            for: metaAccount,
            cryptoType: .sr25519,
            isEthereumBased: false
        ) else {
            XCTFail("Missing substrate account response")
            return
        }

        let publicKeyData = accountResponse.publicKey

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: metaAccount.metaId,
            accountResponse: accountResponse
        )

        let signature = try signer.sign(originalData)

        let verifier = SNSignatureVerifier()

        let publicKey = try SNPublicKey(rawData: publicKeyData)
        let irsignature = try SNSignature(rawData: signature.rawData())

        XCTAssertTrue(verifier.verify(irsignature,
                                      forOriginalData: originalData,
                                      using: publicKey))
    }

    private func performEd25519SigningTest(keychain: KeystoreProtocol,
                                           settings: SelectedWalletSettings) throws {
        let originalData = Self.message.data(using: .utf8)!

        let metaAccount = try XCTUnwrap(settings.value)

        guard let accountResponse = makeChainAccountResponse(
            for: metaAccount,
            cryptoType: .ed25519,
            isEthereumBased: false
        ) else {
            XCTFail("Missing substrate account response")
            return
        }

        let publicKeyData = accountResponse.publicKey

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: metaAccount.metaId,
            accountResponse: accountResponse
        )

        let signature = try signer.sign(originalData)

        let verifier = EDSignatureVerifier()

        let publicKey = try EDPublicKey(rawData: publicKeyData)

        XCTAssertTrue(verifier.verify(signature,
                                      forOriginalData: originalData,
                                      usingPublicKey: publicKey))
    }

    private func performSubstrateEcdsaSigningTest(keychain: KeystoreProtocol,
                                           settings: SelectedWalletSettings) throws {
        let originalData = Self.message.data(using: .utf8)!

        let metaAccount = try XCTUnwrap(settings.value)

        guard let accountResponse = makeChainAccountResponse(
            for: metaAccount,
            cryptoType: .ecdsa,
            isEthereumBased: false
        ) else {
            XCTFail("Missing substrate account response")
            return
        }

        let publicKeyData = accountResponse.publicKey

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: metaAccount.metaId,
            accountResponse: accountResponse
        )

        let signature = try signer.sign(originalData)

        let verifier = SECSignatureVerifier()

        let publicKey = try SECPublicKey(rawData: publicKeyData)

        let verificationData = try originalData.blake2b32()
        XCTAssertTrue(verifier.verify(signature,
                                      forOriginalData: verificationData,
                                      usingPublicKey: publicKey))
    }

    private func performEthereumEcdsaSigningTest(keychain: KeystoreProtocol,
                                           settings: SelectedWalletSettings) throws {
        let originalData = Self.message.data(using: .utf8)!

        let metaAccount = try XCTUnwrap(settings.value)
        guard let accountResponse = makeChainAccountResponse(
            for: metaAccount,
            cryptoType: .ecdsa,
            isEthereumBased: true
        ) else {
            XCTFail("Missing ethereum account response")
            return
        }

        let publicKeyData = accountResponse.publicKey

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: metaAccount.metaId,
            accountResponse: accountResponse
        )

        let signature = try signer.sign(originalData)

        let verifier = SECSignatureVerifier()

        let publicKey = try SECPublicKey(rawData: publicKeyData)

        let verificationData = try originalData.keccak256()
        XCTAssertTrue(verifier.verify(signature,
                                      forOriginalData: verificationData,
                                      usingPublicKey: publicKey))
    }

    private func makeChainAccountResponse(
        for metaAccount: MetaAccountModel,
        cryptoType: CryptoType,
        isEthereumBased: Bool,
        isChainAccount: Bool = false,
        addressPrefix: UInt16 = 0
    ) -> ChainAccountResponse? {
        if isEthereumBased {
            guard
                let accountId = metaAccount.ethereumAddress,
                let publicKey = metaAccount.ethereumPublicKey
            else {
                return nil
            }

            return ChainAccountResponse(
                chainId: "test-chain",
                accountId: accountId,
                publicKey: publicKey,
                name: metaAccount.name,
                cryptoType: cryptoType,
                addressPrefix: addressPrefix,
                isEthereumBased: true,
                isChainAccount: isChainAccount,
                walletId: metaAccount.metaId
            )
        } else {
            guard let accountId = metaAccount.substrateAccountId, let publicKey = metaAccount.substratePublicKey else { return nil }
            return ChainAccountResponse(
                chainId: "test-chain",
                accountId: accountId,
                publicKey: publicKey,
                name: metaAccount.name,
                cryptoType: cryptoType,
                addressPrefix: addressPrefix,
                isEthereumBased: false,
                isChainAccount: isChainAccount,
                walletId: metaAccount.metaId
            )
        }
    }
}

extension SigningWrapperTests {
    func testDeniedMutationNeverReadsWalletKey() throws {
        for (crypto, ethereum) in guardedSigningVariants {
            let (wallet, account, keychain) = try guardedSigningFixture(crypto: crypto, ethereum: ethereum)
            let authorization = try MutationOperationAuthorization(
                intentSha256: String(repeating: "a", count: 64), validateContext: {}
            ) { _ in throw MutationAuthorizationError.denied }
            let signer = SigningWrapper(keystore: keychain, metaId: wallet.metaId,
                                        accountResponse: account, mutationAuthorization: authorization)
            XCTAssertThrowsError(try signer.sign(Data(Self.message.utf8)))
            XCTAssertEqual(keychain.fetches, 0)
        }
    }

    func testRevocationDuringKeyReadPreventsNativeSignature() throws {
        for (crypto, ethereum) in guardedSigningVariants {
            let (wallet, account, keychain) = try guardedSigningFixture(crypto: crypto, ethereum: ethereum)
            var allowed = true
            var boundaries = 0
            keychain.afterFetch = { allowed = false }
            let authorization = try MutationOperationAuthorization(
                intentSha256: String(repeating: "a", count: 64), validateContext: {}
            ) { action in
                boundaries += 1
                guard allowed else { throw MutationAuthorizationError.denied }
                try action()
            }
            let signer = SigningWrapper(keystore: keychain, metaId: wallet.metaId,
                                        accountResponse: account, mutationAuthorization: authorization)
            XCTAssertThrowsError(try signer.sign(Data(Self.message.utf8)))
            XCTAssertEqual(keychain.fetches, 1)
            XCTAssertEqual(boundaries, 2, "Native preparation must be followed by a separate authorization")
        }
    }

    func testAuthorizedSignaturesVerifyOriginalWalletIdentityAndCannotBeReused() throws {
        for (crypto, ethereum) in guardedSigningVariants {
            let (wallet, account, keychain) = try guardedSigningFixture(crypto: crypto, ethereum: ethereum)
            var boundaries = 0
            let authorization = try MutationOperationAuthorization(
                intentSha256: String(repeating: "a", count: 64), validateContext: {}
            ) { action in boundaries += 1; try action() }
            let signer = SigningWrapper(keystore: keychain, metaId: wallet.metaId,
                                        accountResponse: account, mutationAuthorization: authorization)
            let original = Data(Self.message.utf8)
            let signature = try signer.sign(original)
            if ethereum || crypto == .ecdsa {
                let digest = try ethereum ? original.keccak256() : original.blake2b32()
                XCTAssertTrue(SECSignatureVerifier().verify(signature, forOriginalData: digest,
                                                           usingPublicKey: try SECPublicKey(rawData: account.publicKey)))
            } else if crypto == .ed25519 {
                XCTAssertTrue(EDSignatureVerifier().verify(signature, forOriginalData: original,
                                                          usingPublicKey: try EDPublicKey(rawData: account.publicKey)))
            } else {
                XCTAssertTrue(SNSignatureVerifier().verify(try SNSignature(rawData: signature.rawData()),
                                                          forOriginalData: original,
                                                          using: try SNPublicKey(rawData: account.publicKey)))
            }
            XCTAssertEqual(boundaries, 2)
            XCTAssertEqual(keychain.fetches, 1)
            XCTAssertThrowsError(try signer.sign(Data("another transaction".utf8)))
            XCTAssertEqual(keychain.fetches, 1)
        }
    }

    private var guardedSigningVariants: [(CryptoType, Bool)] {
        [(.sr25519, false), (.ed25519, false), (.ecdsa, false), (.ecdsa, true)]
    }

    private func guardedSigningFixture(crypto: CryptoType, ethereum: Bool) throws
        -> (MetaAccountModel, ChainAccountResponse, MutationTrackingKeychain) {
        let keychain = InMemoryKeychain()
        let settings = Self.testSettings
        try AccountCreationHelper.createMetaAccountFromSeed(
            substrateSeed: Self.substrateSeed, ethereumSeed: Self.ethereumSeed,
            cryptoType: crypto, keychain: keychain, settings: settings
        )
        let wallet = try XCTUnwrap(settings.value)
        let account = try XCTUnwrap(makeChainAccountResponse(for: wallet, cryptoType: crypto,
                                                             isEthereumBased: ethereum))
        return (wallet, account, MutationTrackingKeychain(base: keychain))
    }
}

private final class MutationTrackingKeychain: KeystoreProtocol {
    let base: KeystoreProtocol
    var fetches = 0
    var afterFetch: (() -> Void)?
    init(base: KeystoreProtocol) { self.base = base }
    func addKey(_ key: Data, with identifier: String) throws { try base.addKey(key, with: identifier) }
    func updateKey(_ key: Data, with identifier: String) throws { try base.updateKey(key, with: identifier) }
    func fetchKey(for identifier: String) throws -> Data {
        fetches += 1
        let value = try base.fetchKey(for: identifier)
        afterFetch?()
        return value
    }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
    func deleteKey(for identifier: String) throws { try base.deleteKey(for: identifier) }
}
