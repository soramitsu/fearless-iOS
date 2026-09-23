@testable import fearless
import CoreData
import IrohaCrypto
import SoraKeystore
import SSFModels
import XCTest

final class IOSPasskeyWalletMaterialPreflightTests: XCTestCase {
    func testCountsAllRootsWithoutReturningMaterialOrChangingBackupState() throws {
        let substrate = try substrateWallet()
        let native = try LegacyNativeTonFixture.wallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(substrate.metaId): Data(repeating: 0x11, count: 64),
            fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(native.metaId): try LegacyNativeTonFixture.privateKey(),
            fearless.KeystoreTagV2.entropyTagForMetaId(native.metaId): Data(LegacyNativeTonFixture.phrase.utf8)
        ])
        let preflight = makePreflight([projection(substrate), projection(native)], keys: keys)

        let inventory = try preflight.inspect()

        XCTAssertEqual(inventory.walletCount, 2)
        XCTAssertEqual(inventory.substrateRootCount, 1)
        XCTAssertEqual(inventory.ethereumRootCount, 0)
        XCTAssertEqual(inventory.nativeTonRootCount, 1)
        XCTAssertEqual(inventory.chainAccountCount, 0)
        XCTAssertEqual(String(reflecting: inventory), "IOSPasskeyWalletMaterialInventory(<redacted>)")
        XCTAssertFalse(substrate.hasBackup)
        XCTAssertFalse(native.hasBackup)
    }

    func testNativeTonPhraseAlonePreservesOriginalSigningAndExportMaterial() throws {
        let native = try LegacyNativeTonFixture.wallet()
        let phraseTag = fearless.KeystoreTagV2.entropyTagForMetaId(native.metaId)
        let privateTag = fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(native.metaId)
        let keys = PreflightKeystore(keys: [phraseTag: Data(LegacyNativeTonFixture.phrase.utf8)])
        XCTAssertEqual(try makePreflight([projection(native)], keys: keys).inspect().nativeTonRootCount, 1)

        keys.keys.removeValue(forKey: phraseTag)
        keys.keys[privateTag] = try LegacyNativeTonFixture.privateKey()
        XCTAssertThrowsError(try makePreflight([projection(native)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .missingSecretMaterial)
        }
    }

    func testQuarantinedOrUnsupportedRowBlocksEntireInventory() throws {
        let wallet = try substrateWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): Data(repeating: 0x11, count: 64)
        ])
        for state: MetaAccountSelectionRecordState in [.corrupt, .unsupported] {
            let quarantined = MetaAccountSelectionModel(
                identifier: "unavailable-row", wallet: nil, isSelected: false,
                order: 1, recordState: state
            )
            XCTAssertThrowsError(try makePreflight([projection(wallet), quarantined], keys: keys).inspect()) {
                XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .unavailableWalletRecord)
            }
        }
    }

    func testRawRowCountRejectsAProjectionLostDuringMapping() throws {
        let wallet = try substrateWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): Data(repeating: 0x11, count: 64)
        ])
        let projections = [projection(wallet)]
        let preflight = IOSPasskeyWalletMaterialPreflight(
            readProjections: { projections }, readPersistedCount: { 2 }, keystore: keys
        )
        XCTAssertThrowsError(try preflight.inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .unavailableWalletRecord)
        }
    }

    func testProductionReaderIncludesPersistedQuarantinedRows() throws {
        let facade = UserDataStorageTestFacade()
        let inserted = expectation(description: "Persist unsupported wallet row")
        var insertionError: Error?
        facade.databaseService.performAsync { context, error in
            do {
                if let error { throw error }
                guard let context else { throw IOSPasskeyWalletMaterialPreflightError.unavailableWalletStore }
                let row = CDMetaAccount(context: context)
                row.metaId = "unsupported-native-ton-row"
                row.name = "Historical TON"
                row.isSelected = false
                row.order = 1
                row.canExportEthereumMnemonic = false
                row.hasBackup = false
                row.favouriteChainIds = NSArray()
                row.setValue(Data(repeating: 0x41, count: 36), forKey: "tonAddress")
                row.setValue(Data(repeating: 0x42, count: 32), forKey: "tonPublicKey")
                row.setValue("v5R1", forKey: "tonContractVersion")
                try context.save()
            } catch {
                insertionError = error
            }
            inserted.fulfill()
        }
        wait(for: [inserted], timeout: Constants.defaultExpectationDuration)
        if let insertionError { throw insertionError }

        XCTAssertThrowsError(try IOSPasskeyWalletMaterialPreflight(
            storageFacade: facade, keystore: PreflightKeystore()
        ).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .unavailableWalletRecord)
        }
    }

    func testMissingAndLockedRootKeysFailClosed() throws {
        let wallet = try substrateWallet()
        let tag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: PreflightKeystore()).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .missingSecretMaterial)
        }
        XCTAssertThrowsError(try makePreflight(
            [projection(wallet)], keys: PreflightKeystore(errors: [tag: KeystoreError.unexpectedFail])
        ).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .unavailableSecretMaterial)
        }
    }

    func testIndependentEthereumRootRequiresItsOwnMatchingKeyAndBoundPublicIdentity() throws {
        let wallet = try substrateWallet(includeEthereum: true)
        let substrateTag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let ethereumTag = fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [substrateTag: Data(repeating: 0x22, count: 64)])
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .missingSecretMaterial)
        }
        keys.keys[ethereumTag] = ethereumPrivateKey
        XCTAssertEqual(try makePreflight([projection(wallet)], keys: keys).inspect().ethereumRootCount, 1)

        keys.keys[ethereumTag] = Data(repeating: 0x02, count: 32)
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
        keys.keys[ethereumTag] = ethereumPrivateKey

        let mismatched = wallet.replacingEthereumAddress(Data(repeating: 0x44, count: 20))
        XCTAssertThrowsError(try makePreflight([projection(mismatched)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
    }

    func testIndependentChainAccountCannotDisappearBehindRootWalletMaterial() throws {
        let base = try substrateWallet()
        let publicKey = Data(repeating: 0x31, count: 32)
        let accountId = try publicKey.publicKeyToAccountId()
        let chain = ChainAccountModel(
            chainId: "independent:substrate", accountId: accountId, publicKey: publicKey,
            cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
        )
        let wallet = base.insertingChainAccount(chain)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): Data(repeating: 0x11, count: 64)
        ])
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .missingSecretMaterial)
        }
        keys.keys[fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)] =
            Data(repeating: 0x32, count: 32)
        XCTAssertEqual(try makePreflight([projection(wallet)], keys: keys).inspect().chainAccountCount, 1)
    }

    func testAppOwnedBitcoinRequiresOriginalRootAndMatchingPublicKey() throws {
        let base = try substrateWallet()
        let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let derived = try BitcoinKeyDerivation.deriveAccount(mnemonic: phrase, network: .mainnet)
        let chain = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId, accountId: derived.publicKey,
            publicKey: derived.publicKey, cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: false
        )
        let wallet = base.insertingChainAccount(chain)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): Data(repeating: 0x11, count: 64)
        ])
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
        keys.keys[fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId)] = try IRMnemonicCreator()
            .mnemonic(fromList: phrase).entropy()
        XCTAssertEqual(try makePreflight([projection(wallet)], keys: keys).inspect().chainAccountCount, 1)
    }

    func testPendingMigrationAndWalletChangesBlockPreflight() throws {
        let wallet = try substrateWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): Data(repeating: 0x11, count: 64),
            KeystoreMigrator.pendingCleanupIdentifier: Data("pending".utf8)
        ])
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .pendingKeyMigration)
        }
        keys.keys.removeValue(forKey: KeystoreMigrator.pendingCleanupIdentifier)

        var reads = 0
        let drifting = IOSPasskeyWalletMaterialPreflight(readProjections: {
            reads += 1
            return [self.projection(reads == 1 ? wallet : wallet.replacingName("changed"))]
        }, keystore: keys)
        XCTAssertThrowsError(try drifting.inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .walletStoreChanged)
        }
        XCTAssertEqual(reads, 2)
    }

    func testEmptyAndDuplicateWalletSetsFailClosed() throws {
        XCTAssertThrowsError(try makePreflight([], keys: PreflightKeystore()).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .noWallets)
        }
        let wallet = try substrateWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): Data(repeating: 0x11, count: 64)
        ])
        XCTAssertThrowsError(try makePreflight([projection(wallet), projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .duplicateWalletIdentifier)
        }
    }

    private func substrateWallet(includeEthereum: Bool = false) throws -> MetaAccountModel {
        let publicKey = Data(repeating: 0x21, count: 32)
        let ethereumPublicKey = includeEthereum ? try SECKeyFactory()
            .derive(fromPrivateKey: SECPrivateKey(rawData: ethereumPrivateKey))
            .publicKey().rawData() : nil
        return MetaAccountModel(
            metaId: "preflight-wallet", name: "Wallet", substrateAccountId: try publicKey.publicKeyToAccountId(),
            substrateCryptoType: CryptoType.ed25519.rawValue, substratePublicKey: publicKey,
            ethereumAddress: try ethereumPublicKey?.ethereumAddressFromPublicKey(),
            ethereumPublicKey: ethereumPublicKey, chainAccounts: [], assetKeysOrder: nil,
            canExportEthereumMnemonic: false, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil,
            assetsVisibility: [], hasBackup: false, favouriteChainIds: []
        )
    }

    private func projection(_ wallet: MetaAccountModel) -> MetaAccountSelectionModel {
        MetaAccountSelectionModel(identifier: wallet.metaId, wallet: wallet, isSelected: false, order: 0)
    }

    private var ethereumPrivateKey: Data { Data(repeating: 0x01, count: 32) }

    private func makePreflight(
        _ projections: [MetaAccountSelectionModel], keys: PreflightKeystore
    ) -> IOSPasskeyWalletMaterialPreflight {
        IOSPasskeyWalletMaterialPreflight(readProjections: { projections }, keystore: keys)
    }
}

private final class PreflightKeystore: KeystoreProtocol {
    var keys: [String: Data]
    let errors: [String: Error]

    init(keys: [String: Data] = [:], errors: [String: Error] = [:]) {
        self.keys = keys
        self.errors = errors
    }

    func addKey(_ key: Data, with identifier: String) throws { keys[identifier] = key }
    func updateKey(_ key: Data, with identifier: String) throws { keys[identifier] = key }
    func fetchKey(for identifier: String) throws -> Data {
        if let error = errors[identifier] { throw error }
        guard let key = keys[identifier] else { throw KeystoreError.noKeyFound }
        return key
    }
    func checkKey(for identifier: String) throws -> Bool { keys[identifier] != nil }
    func deleteKey(for identifier: String) throws { keys.removeValue(forKey: identifier) }
}
