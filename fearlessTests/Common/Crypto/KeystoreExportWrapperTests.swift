import XCTest
@testable import fearless
import IrohaCrypto
import SoraKeystore
import SSFCrypto
import SSFModels
import SSFUtils

final class KeystoreExportWrapperTests: XCTestCase {
    private let exportPassword = "public-test-export-password"

    func testHistoricalSr25519ExportRetainsOriginalKeys() throws {
        try roundTrip(makeFixture(cryptoType: .sr25519))
    }

    func testHistoricalEd25519ExportRetainsOriginalKeys() throws {
        try roundTrip(makeFixture(cryptoType: .ed25519))
    }

    func testHistoricalEcdsaExportRetainsOriginalKeys() throws {
        try roundTrip(makeFixture(cryptoType: .ecdsa))
    }

    func testStandaloneEthereumExportRetainsIndependentOriginalKey() throws {
        try roundTrip(makeFixture(cryptoType: .ecdsa, ethereum: true))
    }

    func testSubstrateChainSpecificExportUsesOnlyItsOriginalKey() throws {
        try roundTrip(makeFixture(cryptoType: .sr25519, chainSpecific: true))
    }

    func testEthereumChainSpecificExportUsesOnlyItsOriginalKey() throws {
        try roundTrip(makeFixture(cryptoType: .ecdsa, ethereum: true, chainSpecific: true))
    }

    func testMissingWalletKeyFailsWithoutFallingBackToAnotherWallet() throws {
        let fixture = try makeFixture(cryptoType: .sr25519)
        XCTAssertThrowsError(try KeystoreExportWrapper(keystore: fixture.keystore).export(
            chainAccount: fixture.account,
            password: exportPassword,
            address: fixture.address,
            metaId: "different-wallet",
            accountId: nil,
            genesisHash: nil
        ))
        XCTAssertEqual(try fixture.keystore.fetchKey(for: fixture.tag), fixture.secret)
    }

    func testExportRequiresCorrectPasswordAndRejectsTamperedCiphertext() throws {
        let fixture = try makeFixture(cryptoType: .ed25519)
        let exported = try export(fixture)
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: exported)
        XCTAssertThrowsError(try KeystoreExtractor().extractFromDefinition(definition, password: "wrong"))

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: exported) as? [String: Any])
        var encrypted = try XCTUnwrap(Data(base64Encoded: definition.encoded))
        encrypted[encrypted.count - 1] ^= 1
        object["encoded"] = encrypted.base64EncodedString()
        let tampered = try JSONDecoder().decode(
            KeystoreDefinition.self, from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertThrowsError(try KeystoreExtractor().extractFromDefinition(tampered, password: exportPassword))
        XCTAssertEqual(try fixture.keystore.fetchKey(for: fixture.tag), fixture.secret)
    }

    private struct Fixture {
        let keystore: InMemoryKeychain
        let account: ChainAccountResponse
        let address: String
        let tag: String
        let secret: Data
    }

    private func makeFixture(
        cryptoType: CryptoType,
        ethereum: Bool = false,
        chainSpecific: Bool = false
    ) throws -> Fixture {
        let keystore = InMemoryKeychain()
        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue()
        )
        let name: String
        let password: String
        switch cryptoType {
        case .sr25519:
            name = Constants.validSrKeystoreName
            password = Constants.validSrKeystorePassword
        case .ed25519:
            name = Constants.validEd25519KeystoreName
            password = Constants.validEd25519KeystorePassword
        case .ecdsa:
            name = Constants.validEcdsaKeystoreName
            password = Constants.validEcdsaKeystorePassword
        }
        let bundle = Bundle(for: Self.self)
        let substrateURL = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        let ethereumURL = try XCTUnwrap(bundle.url(forResource: Constants.validEthereumKeystoreName, withExtension: "json"))
        try AccountCreationHelper.createMetaAccountFromKeystoreData(
            substrateData: Data(contentsOf: substrateURL),
            ethereumData: ethereum ? Data(contentsOf: ethereumURL) : nil,
            substratePassword: password,
            ethereumPassword: ethereum ? Constants.validEthereumKeystorePassword : nil,
            keychain: keystore,
            settings: settings,
            cryptoType: cryptoType
        )
        let wallet = try XCTUnwrap(settings.value)
        let accountId = try XCTUnwrap(ethereum ? wallet.ethereumAddress : wallet.substrateAccountId)
        let publicKey = try XCTUnwrap(ethereum ? wallet.ethereumPublicKey : wallet.substratePublicKey)
        let rootTag = ethereum
            ? fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: nil)
            : fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: nil)
        let secret = try keystore.fetchKey(for: rootTag)
        let tag = ethereum
            ? fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: chainSpecific ? accountId : nil)
            : fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: chainSpecific ? accountId : nil)
        if chainSpecific {
            try keystore.addKey(secret, with: tag)
            // A chain-account export must not fall back to a root key.
            try keystore.deleteKey(for: rootTag)
        }
        let account = ChainAccountResponse(
            chainId: "legacy-export-fixture", accountId: accountId, publicKey: publicKey,
            name: wallet.name, cryptoType: cryptoType, addressPrefix: 42,
            isEthereumBased: ethereum, isChainAccount: chainSpecific, walletId: wallet.metaId
        )
        return Fixture(
            keystore: keystore, account: account,
            address: try accountId.toAddress(using: ethereum ? .sfEthereum : .sfSubstrate(42)),
            tag: tag, secret: secret
        )
    }

    private func export(_ fixture: Fixture) throws -> Data {
        try KeystoreExportWrapper(keystore: fixture.keystore).export(
            chainAccount: fixture.account, password: exportPassword, address: fixture.address,
            metaId: fixture.account.walletId,
            accountId: fixture.account.isChainAccount ? fixture.account.accountId : nil,
            genesisHash: nil
        )
    }

    private func roundTrip(_ fixture: Fixture) throws {
        let exported = try export(fixture)
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: exported)
        let recovered = try KeystoreExtractor().extractFromDefinition(definition, password: exportPassword)
        XCTAssertEqual(recovered.secretKeyData, fixture.secret)
        XCTAssertEqual(recovered.publicKeyData, fixture.account.publicKey)
        XCTAssertEqual(recovered.cryptoType, fixture.account.cryptoType)
        XCTAssertEqual(recovered.address, fixture.address)
        XCTAssertEqual(try fixture.keystore.fetchKey(for: fixture.tag), fixture.secret)
        XCTAssertEqual(definition.encoding.type, ["scrypt", "xsalsa20-poly1305"])
    }
}
