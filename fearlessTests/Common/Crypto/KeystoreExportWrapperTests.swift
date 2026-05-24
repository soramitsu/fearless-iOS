import XCTest
import FearlessSecureStorage
import SSFModels
import SSFUtils
@testable import fearless

final class KeystoreExportWrapperTests: XCTestCase {
    private let substrateSeed = "18691a833f2c7f8c8738519ad04ac8e1ce16fc160c738ce36708defbd841e23c"
    private let ethereumSeed = "0xe0fa453f7646c45cbeecac10d4f48eb90868ec15d91cf0a46d9cf974f7862edf"
    private let password = "export-password"

    func testSr25519Export_whenDecoded_thenPreservesKeyMaterialAndMetadata() throws {
        try performSubstrateExportTest(cryptoType: .sr25519)
    }

    func testEd25519Export_whenDecoded_thenPreservesKeyMaterialAndMetadata() throws {
        try performSubstrateExportTest(cryptoType: .ed25519)
    }

    func testEthereumEcdsaExport_whenDecoded_thenUsesEthereumEncodingAndKeyMaterial() throws {
        let keychain = InMemoryKeychain()
        let settings = Self.makeSettings()

        try AccountCreationHelper.createMetaAccountFromSeed(
            substrateSeed: substrateSeed,
            ethereumSeed: ethereumSeed,
            cryptoType: .ecdsa,
            keychain: keychain,
            settings: settings
        )

        let wallet = try XCTUnwrap(settings.value)
        let account = try makeEthereumAccountResponse(wallet: wallet)
        let definition = try exportDefinition(
            chainAccount: account,
            keychain: keychain,
            metaId: wallet.metaId,
            address: "0xreceiver",
            genesisHash: nil
        )
        let extracted = try KeystoreExtractor().extractFromDefinition(definition, password: password)
        let expectedSecret = try keychain.fetchKey(
            for: fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)
        )

        XCTAssertEqual(definition.address, "0xreceiver")
        XCTAssertEqual(definition.encoding.content, ["pkcs8", "ethereum"])
        XCTAssertEqual(definition.meta?.name, wallet.name)
        XCTAssertEqual(definition.meta?.isHardware, false)
        XCTAssertEqual(definition.meta?.tags, [])
        XCTAssertNil(definition.meta?.genesisHash)
        XCTAssertEqual(extracted.secretKeyData, expectedSecret)
        XCTAssertEqual(extracted.publicKeyData, account.publicKey)
        XCTAssertEqual(extracted.cryptoType, .ecdsa)
    }

    private func performSubstrateExportTest(cryptoType: CryptoType) throws {
        let keychain = InMemoryKeychain()
        let settings = Self.makeSettings()

        try AccountCreationHelper.createMetaAccountFromSeed(
            substrateSeed: substrateSeed,
            ethereumSeed: nil,
            cryptoType: cryptoType,
            keychain: keychain,
            settings: settings
        )

        let wallet = try XCTUnwrap(settings.value)
        let account = makeSubstrateAccountResponse(wallet: wallet, cryptoType: cryptoType)
        let definition = try exportDefinition(
            chainAccount: account,
            keychain: keychain,
            metaId: wallet.metaId,
            address: "substrate-address",
            genesisHash: Chain.polkadot.genesisHash
        )
        let extracted = try KeystoreExtractor().extractFromDefinition(definition, password: password)
        let expectedSecret = try keychain.fetchKey(
            for: fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        )

        XCTAssertEqual(definition.address, "substrate-address")
        XCTAssertEqual(definition.encoding.content, ["pkcs8", cryptoType.stringValue])
        XCTAssertEqual(definition.meta?.name, wallet.name)
        XCTAssertEqual(definition.meta?.genesisHash, "0x\(Chain.polkadot.genesisHash)")
        XCTAssertNil(definition.meta?.isHardware)
        XCTAssertNil(definition.meta?.tags)
        XCTAssertEqual(extracted.secretKeyData, expectedSecret)
        XCTAssertEqual(extracted.publicKeyData, account.publicKey)
        XCTAssertEqual(extracted.cryptoType, cryptoType)
    }

    private func exportDefinition(
        chainAccount: ChainAccountResponse,
        keychain: KeystoreProtocol,
        metaId: String,
        address: String,
        genesisHash: String?
    ) throws -> KeystoreDefinition {
        let exportData = try KeystoreExportWrapper(keystore: keychain).export(
            chainAccount: chainAccount,
            password: password,
            address: address,
            metaId: metaId,
            accountId: nil,
            genesisHash: genesisHash
        )

        return try JSONDecoder().decode(KeystoreDefinition.self, from: exportData)
    }

    private func makeSubstrateAccountResponse(
        wallet: MetaAccountModel,
        cryptoType: CryptoType
    ) -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: Chain.polkadot.genesisHash,
            accountId: wallet.substrateAccountId,
            publicKey: wallet.substratePublicKey,
            name: wallet.name,
            cryptoType: cryptoType,
            addressPrefix: 0,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: wallet.metaId
        )
    }

    private func makeEthereumAccountResponse(wallet: MetaAccountModel) throws -> ChainAccountResponse {
        ChainAccountResponse(
            chainId: "ethereum",
            accountId: try XCTUnwrap(wallet.ethereumAddress),
            publicKey: try XCTUnwrap(wallet.ethereumPublicKey),
            name: wallet.name,
            cryptoType: .ecdsa,
            addressPrefix: 0,
            isEthereumBased: true,
            isChainAccount: false,
            walletId: wallet.metaId
        )
    }

    private static func makeSettings() -> SelectedWalletSettings {
        SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )
    }
}
