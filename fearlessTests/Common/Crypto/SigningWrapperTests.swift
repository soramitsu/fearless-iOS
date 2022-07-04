import XCTest
@testable import fearless
import IrohaCrypto
import SoraKeystore

class SigningWrapperTests: XCTestCase {
    static let name: String = "myname"
    static let message: String = "this is a message"
    static let substrateSeed: String = "18691a833f2c7f8c8738519ad04ac8e1ce16fc160c738ce36708defbd841e23c"
    static let ethereumSeed: String = "0xe0fa453f7646c45cbeecac10d4f48eb90868ec15d91cf0a46d9cf974f7862edf"

    private static var testSettings: SelectedWalletSettings = {
        SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
    }()

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

        try AccountCreationHelper.createMetaAccountFromKeystore(substrateFilename: Constants.validSrKeystoreName,
                                                                ethereumFilename: nil,
                                                                substratePassword: Constants.validSrKeystorePassword,
                                                                ethereumPassword: nil,
                                                                keychain: keychain,
                                                                settings: settings)

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

        try AccountCreationHelper.createMetaAccountFromKeystore(substrateFilename: Constants.validEd25519KeystoreName,
                                                                ethereumFilename: nil,
                                                                substratePassword: Constants.validEd25519KeystorePassword,
                                                                ethereumPassword: nil,
                                                                keychain: keychain,
                                                                settings: settings)

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

        try AccountCreationHelper.createMetaAccountFromKeystore(substrateFilename: Constants.validEcdsaKeystoreName,
                                                                ethereumFilename: Constants.validEthereumKeystoreName,
                                                                substratePassword: Constants.validEcdsaKeystorePassword,
                                                                ethereumPassword: Constants.validEthereumKeystorePassword,
                                                                keychain: keychain,
                                                                settings: settings)

        try performSubstrateEcdsaSigningTest(keychain: keychain, settings: settings)
        try performEthereumEcdsaSigningTest(keychain: keychain, settings: settings)
    }

    // MARK: Private

    private func performSr25519SigningTest(keychain: KeystoreProtocol,
                                           settings: SelectedWalletSettings) throws {
        let originalData = Self.message.data(using: .utf8)!

        guard let metaAccount = settings.value else { return }

        let publicKeyData = metaAccount.substratePublicKey

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: metaAccount.metaId,
            accountId: nil,
            isEthereumBased: false,
            cryptoType: .sr25519,
            publicKeyData: publicKeyData
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

        guard let metaAccount = settings.value else { return }

        let publicKeyData = metaAccount.substratePublicKey

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: metaAccount.metaId,
            accountId: nil,
            isEthereumBased: false,
            cryptoType: .ed25519,
            publicKeyData: publicKeyData
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

        guard let metaAccount = settings.value else { return }

        let publicKeyData = metaAccount.substratePublicKey

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: metaAccount.metaId,
            accountId: nil,
            isEthereumBased: false,
            cryptoType: .ecdsa,
            publicKeyData: publicKeyData
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

        guard let metaAccount = settings.value else { return }
        guard let publicKeyData = metaAccount.ethereumPublicKey else { return }

        let signer = SigningWrapper(
            keystore: keychain,
            metaId: metaAccount.metaId,
            accountId: nil,
            isEthereumBased: true,
            cryptoType: .ecdsa,
            publicKeyData: publicKeyData
        )

        let signature = try signer.sign(originalData)

        let verifier = SECSignatureVerifier()

        let publicKey = try SECPublicKey(rawData: publicKeyData)

        let verificationData = try originalData.keccak256()
        XCTAssertTrue(verifier.verify(signature,
                                      forOriginalData: verificationData,
                                      usingPublicKey: publicKey))
    }
}
