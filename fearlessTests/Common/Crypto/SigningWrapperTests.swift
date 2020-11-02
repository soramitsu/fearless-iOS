import XCTest
@testable import fearless
import IrohaCrypto
import SoraKeystore

class SigningWrapperTests: XCTestCase {
    static let name: String = "myname"
    static let message: String = "this is a message"
    static let seed: String = "18691a833f2c7f8c8738519ad04ac8e1ce16fc160c738ce36708defbd841e23c"

    func testSr25519CreationFromMnemonicAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        try performSr25519SigningTest(keychain: keychain, settings: settings)
    }

    func testSr25519CreationFromSeedAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromSeed(Self.seed,
                                                        cryptoType: .sr25519,
                                                        keychain: keychain,
                                                        settings: settings)

        try performSr25519SigningTest(keychain: keychain, settings: settings)
    }

    func testSr25519CreationFromKeystoreAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromKeystore(Constants.validSrKeystoreName,
                                                            password: Constants.validSrKeystorePassword,
                                                            keychain: keychain,
                                                            settings: settings)

        try performSr25519SigningTest(keychain: keychain, settings: settings)
    }

    func testEd25519CreationFromMnemonicAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .ed25519,
                                                            keychain: keychain,
                                                            settings: settings)

        try performEd25519SigningTest(keychain: keychain, settings: settings)
    }

    func testEd25519CreationFromSeedAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromSeed(Self.seed,
                                                        cryptoType: .ed25519,
                                                        keychain: keychain,
                                                        settings: settings)

        try performEd25519SigningTest(keychain: keychain, settings: settings)
    }

    func testEd25519CreationFromKeystoreAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromKeystore(Constants.validEd25519KeystoreName,
                                                            password: Constants.validEd25519KeystorePassword,
                                                            keychain: keychain,
                                                            settings: settings)

        try performEd25519SigningTest(keychain: keychain, settings: settings)
    }

    func testEcdsaCreationFromMnemonicAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .ecdsa,
                                                            keychain: keychain,
                                                            settings: settings)

        try performEcdsaSigningTest(keychain: keychain, settings: settings)
    }

    func testEcdsaCreationFromSeedAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromSeed(Self.seed,
                                                        cryptoType: .ecdsa,
                                                        keychain: keychain,
                                                        settings: settings)

        try performEcdsaSigningTest(keychain: keychain, settings: settings)
    }

    func testEcdsaCreationFromKeystoreAndSigning() throws {
        let keychain = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        try AccountCreationHelper.createAccountFromKeystore(Constants.validEcdsaKeystoreName,
                                                            password: Constants.validEcdsaKeystorePassword,
                                                            keychain: keychain,
                                                            settings: settings)

        try performEcdsaSigningTest(keychain: keychain, settings: settings)
    }

    // MARK: Private

    private func performSr25519SigningTest(keychain: KeystoreProtocol,
                                           settings: SettingsManagerProtocol) throws {
        let originalData = Self.message.data(using: .utf8)!

        let signer = SigningWrapper(keystore: keychain, settings: settings)

        let signature = try signer.sign(originalData)

        let verifier = SNSignatureVerifier()

        guard let publicKeyData = settings.selectedAccount?.publicKeyData else {
            return
        }

        let publicKey = try SNPublicKey(rawData: publicKeyData)
        let irsignature = try SNSignature(rawData: signature.rawData())

        XCTAssertTrue(verifier.verify(irsignature,
                                      forOriginalData: originalData,
                                      using: publicKey))
    }

    private func performEd25519SigningTest(keychain: KeystoreProtocol,
                                           settings: SettingsManagerProtocol) throws {
        let originalData = Self.message.data(using: .utf8)!

        let signer = SigningWrapper(keystore: keychain, settings: settings)

        let signature = try signer.sign(originalData)

        let verifier = EDSignatureVerifier()

        guard let publicKeyData = settings.selectedAccount?.publicKeyData else {
            return
        }

        let publicKey = try EDPublicKey(rawData: publicKeyData)

        XCTAssertTrue(verifier.verify(signature,
                                      forOriginalData: originalData,
                                      usingPublicKey: publicKey))
    }

    private func performEcdsaSigningTest(keychain: KeystoreProtocol,
                                           settings: SettingsManagerProtocol) throws {
        let originalData = Self.message.data(using: .utf8)!

        let signer = SigningWrapper(keystore: keychain, settings: settings)

        let signature = try signer.sign(originalData)

        let verifier = SECSignatureVerifier()

        guard let publicKeyData = settings.selectedAccount?.publicKeyData else {
            return
        }

        let publicKey = try SECPublicKey(rawData: publicKeyData)

        let verificationData = try originalData.blake2b32()
        XCTAssertTrue(verifier.verify(signature,
                                      forOriginalData: verificationData,
                                      usingPublicKey: publicKey))
    }
}
