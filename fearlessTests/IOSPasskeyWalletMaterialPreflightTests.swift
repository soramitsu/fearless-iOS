@testable import fearless
import CoreData
import IrohaCrypto
import SoraKeystore
import struct SSFCrypto.SeedFactory
import SSFModels
import XCTest

final class IOSPasskeyWalletMaterialPreflightTests: XCTestCase {
    func testCountsAllRootsWithoutReturningMaterialOrChangingBackupState() throws {
        let substrate = try substrateWallet()
        let native = try LegacyNativeTonFixture.wallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(substrate.metaId): substrateSecretKey,
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
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey
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
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey
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

    func testProductionCaptureKeepsPersistedDisplayPreferences() throws {
        let wallet = try substrateWallet()
        let facade = UserDataStorageTestFacade()
        let inserted = expectation(description: "Persist wallet display preferences")
        var insertionError: Error?
        facade.databaseService.performAsync { context, error in
            do {
                if let error { throw error }
                guard let context else { throw IOSPasskeyWalletMaterialPreflightError.unavailableWalletStore }
                let row = CDMetaAccount(context: context)
                row.metaId = wallet.metaId
                row.name = wallet.name
                row.isSelected = true
                row.order = 1
                row.substrateAccountId = wallet.substrateAccountId?.map { String(format: "%02x", $0) }.joined()
                row.substratePublicKey = wallet.substratePublicKey
                row.substrateCryptoType = Int16(wallet.substrateCryptoType)
                row.canExportEthereumMnemonic = false
                row.hasBackup = true
                row.favouriteChainIds = NSArray()
                row.setValue(NSArray(array: ["historical-filter"]), forKey: "assetFilterOptions")
                row.setValue(true, forKey: "zeroBalanceAssetsHidden")
                try context.save()
            } catch {
                insertionError = error
            }
            inserted.fulfill()
        }
        wait(for: [inserted], timeout: Constants.defaultExpectationDuration)
        if let insertionError { throw insertionError }

        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            storageFacade: facade, keystore: keys
        ).capture()
        XCTAssertEqual(draft.wallets.count, 1)
        XCTAssertEqual(draft.wallets[0].displayPreferences.assetFilterOptions, ["historical-filter"])
        XCTAssertTrue(draft.wallets[0].displayPreferences.zeroBalanceAssetsHidden)
        XCTAssertFalse(draft.wallets[0].publicIdentity.hasBackup)
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

    func testSubstrateRootMustSignForItsPersistedPublicIdentity() throws {
        let wallet = try substrateWallet()
        let tag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [tag: substrateSecretKey])
        XCTAssertEqual(try makePreflight([projection(wallet)], keys: keys).inspect().substrateRootCount, 1)

        keys.keys[tag] = Data(repeating: 0x44, count: 64)
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
    }

    func testEcdsaRootMustSignForItsPersistedIdentity() throws {
        let wallet = try substrateWallet(cryptoType: .ecdsa)
        let tag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [tag: Data(repeating: 0x11, count: 32)])
        XCTAssertEqual(try makePreflight([projection(wallet)], keys: keys).inspect().substrateRootCount, 1)

        keys.keys[tag] = Data(repeating: 0x44, count: 32)
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
    }

    func testSr25519RootSignsForItsIdentityAndCorruptKeyFailsWithoutAborting() throws {
        let wallet = try substrateWallet(cryptoType: .sr25519)
        let tag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [tag: try substrateSecretKey(for: .sr25519)])
        XCTAssertEqual(try makePreflight([projection(wallet)], keys: keys).inspect().substrateRootCount, 1)

        keys.keys[tag] = Data(repeating: 0x44, count: 64)
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }

        keys.keys[tag] = try SNKeyFactory().createKeypair(fromSeed: Data(repeating: 0x22, count: 32))
            .privateKey().rawData()
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
    }

    func testIndependentEthereumRootRequiresItsOwnMatchingKeyAndBoundPublicIdentity() throws {
        let wallet = try substrateWallet(includeEthereum: true)
        let substrateTag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let ethereumTag = fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [substrateTag: substrateSecretKey])
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
        let publicKey = try EDKeyFactory().derive(fromSeed: Data(repeating: 0x32, count: 32))
            .publicKey().rawData()
        let accountId = try publicKey.publicKeyToAccountId()
        let chain = ChainAccountModel(
            chainId: "independent:substrate", accountId: accountId, publicKey: publicKey,
            cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
        )
        let wallet = base.insertingChainAccount(chain)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey
        ])
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .missingSecretMaterial)
        }
        keys.keys[fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)] =
            Data(repeating: 0x32, count: 32)
        XCTAssertEqual(try makePreflight([projection(wallet)], keys: keys).inspect().chainAccountCount, 1)

        keys.keys[fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId)] =
            Data(repeating: 0x33, count: 32)
        XCTAssertThrowsError(try makePreflight([projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
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
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey
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
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey,
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
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey
        ])
        XCTAssertThrowsError(try makePreflight([projection(wallet), projection(wallet)], keys: keys).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .duplicateWalletIdentifier)
        }
    }

    func testDraftCapturesMultipleRootsWithoutTrustingPriorBackupState() throws {
        let substrate = try substrateWallet(includeEthereum: true).replacingIsBackuped(true)
        let native = try LegacyNativeTonFixture.wallet()
        let tonPhrase = Data(LegacyNativeTonFixture.phrase.utf8)
        let tonPrivateKey = try LegacyNativeTonFixture.privateKey()
        let historicalEthereumSeed = Data(repeating: 0x42, count: 64)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(substrate.metaId): substrateSecretKey,
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(substrate.metaId): ethereumPrivateKey,
            fearless.KeystoreTagV2.ethereumSeedTagForMetaId(substrate.metaId): historicalEthereumSeed,
            fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(native.metaId): tonPrivateKey,
            fearless.KeystoreTagV2.entropyTagForMetaId(native.metaId): tonPhrase
        ])
        let projections = [
            MetaAccountSelectionModel(
                identifier: substrate.metaId,
                wallet: substrate,
                isSelected: true,
                order: 1,
                displayPreferences: PersistedWalletDisplayPreferences(
                    assetFilterOptions: ["historical-filter"], zeroBalanceAssetsHidden: true
                )
            ),
            MetaAccountSelectionModel(
                identifier: native.metaId,
                wallet: native,
                isSelected: false,
                order: 2,
                displayPreferences: PersistedWalletDisplayPreferences(
                    assetFilterOptions: nil, zeroBalanceAssetsHidden: false
                )
            )
        ]
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight(projections, keys: keys), keystore: keys
        ).capture()

        XCTAssertEqual(draft.wallets.count, 2)
        XCTAssertEqual(draft.wallets.map(\.publicIdentity.metaId), [substrate.metaId, native.metaId])
        XCTAssertTrue(draft.wallets[0].isSelected)
        XCTAssertEqual(draft.wallets[0].order, 1)
        XCTAssertEqual(draft.wallets[0].displayPreferences.assetFilterOptions, ["historical-filter"])
        XCTAssertTrue(draft.wallets[0].displayPreferences.zeroBalanceAssetsHidden)
        XCTAssertFalse(draft.wallets[0].publicIdentity.hasBackup)
        XCTAssertFalse(draft.wallets[1].publicIdentity.hasBackup)
        XCTAssertEqual(
            draft.wallets[0].slots.first(where: { $0.role == .substrateSecret })?.bytes,
            substrateSecretKey
        )
        XCTAssertEqual(
            draft.wallets[0].slots.first(where: { $0.role == .ethereumSecret })?.bytes,
            ethereumPrivateKey
        )
        XCTAssertEqual(
            draft.wallets[0].slots.first(where: { $0.role == .ethereumSeed })?.bytes,
            historicalEthereumSeed
        )
        XCTAssertEqual(
            draft.wallets[1].slots.first(where: { $0.role == .tonSecret })?.bytes,
            tonPrivateKey
        )
        XCTAssertEqual(
            draft.wallets[1].slots.first(where: { $0.role == .entropy })?.bytes,
            tonPhrase
        )
        XCTAssertEqual(String(reflecting: draft), "IOSPasskeyWalletMaterialDraft(<redacted>)")
        XCTAssertEqual(
            String(reflecting: draft.wallets[0].slots[0]),
            "IOSPasskeyWalletMaterialDraft.SecretSlot(<redacted>)"
        )
        var reflectedDraft = ""
        dump(draft, to: &reflectedDraft)
        XCTAssertFalse(reflectedDraft.contains("bytes"))
        var reflectedSlot = ""
        dump(draft.wallets[0].slots[0], to: &reflectedSlot)
        XCTAssertFalse(reflectedSlot.contains("bytes"))
    }

    func testDraftPreservesHistoricalSeedBytesAndRejectsBadMnemonicExport() throws {
        let base = try substrateWallet()
        let seed = Data(repeating: 0x32, count: 32)
        let publicKey = try EDKeyFactory().derive(fromSeed: seed).publicKey().rawData()
        let accountId = try publicKey.publicKeyToAccountId()
        let chain = ChainAccountModel(
            chainId: "independent:substrate", accountId: accountId, publicKey: publicKey,
            cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
        )
        let wallet = base.insertingChainAccount(chain)
        let rootSeed = Data(repeating: 0x42, count: 64)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey,
            fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId): rootSeed,
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: accountId): seed,
            fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: accountId): seed
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([projection(wallet)], keys: keys), keystore: keys
        ).capture()
        let slots = draft.wallets[0].slots
        XCTAssertEqual(
            slots.first(where: { $0.role == .substrateSeed && $0.chainId == nil })?.bytes,
            rootSeed
        )
        XCTAssertEqual(
            slots.first(where: { $0.role == .substrateSecret && $0.chainId == chain.chainId })?.bytes,
            seed
        )
        XCTAssertEqual(
            slots.first(where: { $0.role == .substrateSeed && $0.chainId == chain.chainId })?.bytes,
            seed
        )
        XCTAssertEqual(slots.first(where: { $0.chainId == chain.chainId })?.accountId, accountId)

        keys.keys[fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId)] = Data(repeating: 0x01, count: 16)
        XCTAssertThrowsError(try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([projection(wallet)], keys: keys), keystore: keys
        ).capture()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .unverifiedExportMaterial)
        }
        keys.keys.removeValue(forKey: fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        keys.keys[fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: accountId)] =
            Data(repeating: 0x01, count: 16)
        keys.keys[fearless.KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId, accountId: accountId)] =
            Data("//wrong-chain-path".utf8)
        XCTAssertThrowsError(try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([projection(wallet)], keys: keys), keystore: keys
        ).capture()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .unverifiedExportMaterial)
        }
    }

    func testDraftAcceptsMnemonicThatRederivesOriginalRoot() throws {
        let entropy = Data(repeating: 0x01, count: 16)
        let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)
        let seed = try SeedFactory().deriveSeed(from: mnemonic.toString(), password: "").seed.miniSeed
        let publicKey = try EDKeyFactory().derive(fromSeed: seed).publicKey().rawData()
        let ethereumPath = DerivationPathConstants.defaultEthereum
        let ethereum = try EthereumAccountImportWrapper().importEntropy(entropy, derivationPath: ethereumPath)
        let ethereumPublicKey = try ethereum.keypair.publicKey().rawData()
        let ethereumPrivateKey = try ethereum.keypair.privateKey().rawData()
        let wallet = MetaAccountModel(
            metaId: "mnemonic-proof-wallet", name: "Mnemonic", substrateAccountId: try publicKey.publicKeyToAccountId(),
            substrateCryptoType: CryptoType.ed25519.rawValue, substratePublicKey: publicKey,
            ethereumAddress: try ethereumPublicKey.ethereumAddressFromPublicKey(),
            ethereumPublicKey: ethereumPublicKey, chainAccounts: [], assetKeysOrder: nil,
            canExportEthereumMnemonic: true, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil,
            assetsVisibility: [], hasBackup: false, favouriteChainIds: []
        )
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): seed,
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): entropy,
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey,
            fearless.KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId): Data(ethereumPath.utf8)
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([projection(wallet)], keys: keys), keystore: keys
        ).capture()
        XCTAssertEqual(draft.wallets[0].slots.first(where: { $0.role == .entropy })?.bytes, entropy)
        XCTAssertEqual(
            draft.wallets[0].slots.first(where: { $0.role == .ethereumSecret })?.bytes,
            ethereumPrivateKey
        )
    }

    func testDraftRejectsSecretMutationAfterValidatedRead() throws {
        let wallet = try substrateWallet()
        let tag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [tag: substrateSecretKey])
        var projectionReads = 0
        let preflight = IOSPasskeyWalletMaterialPreflight(readProjections: {
            projectionReads += 1
            if projectionReads == 4 { keys.keys[tag] = Data(repeating: 0x44, count: 64) }
            return [self.projection(wallet)]
        }, keystore: keys)
        XCTAssertThrowsError(
            try IOSPasskeyWalletMaterialDraftCapture(preflight: preflight, keystore: keys).capture()
        ) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .walletStoreChanged)
        }
    }

    func testDraftRejectsKeySubstitutionAfterSigningProof() throws {
        let wallet = try substrateWallet()
        let tag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [tag: substrateSecretKey])
        var projectionReads = 0
        let preflight = IOSPasskeyWalletMaterialPreflight(readProjections: {
            projectionReads += 1
            if projectionReads == 3 { keys.keys[tag] = Data(repeating: 0x44, count: 64) }
            return [self.projection(wallet)]
        }, keystore: keys)
        XCTAssertThrowsError(
            try IOSPasskeyWalletMaterialDraftCapture(preflight: preflight, keystore: keys).capture()
        ) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .walletStoreChanged)
        }
    }

    func testDraftRejectsNewOptionalSlotAppearingDuringCapture() throws {
        let wallet = try substrateWallet()
        let rootTag = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId)
        let optionalTag = fearless.KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [rootTag: substrateSecretKey])
        var projectionReads = 0
        let preflight = IOSPasskeyWalletMaterialPreflight(readProjections: {
            projectionReads += 1
            if projectionReads == 4 { keys.keys[optionalTag] = Data("//new-path".utf8) }
            return [self.projection(wallet)]
        }, keystore: keys)
        XCTAssertThrowsError(
            try IOSPasskeyWalletMaterialDraftCapture(preflight: preflight, keystore: keys).capture()
        ) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .walletStoreChanged)
        }
    }

    func testDraftRejectsLockedOptionalKeychainSlot() throws {
        let wallet = try substrateWallet()
        let optionalTag = fearless.KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(
            keys: [fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey],
            errors: [optionalTag: KeystoreError.unexpectedFail]
        )
        XCTAssertThrowsError(
            try IOSPasskeyWalletMaterialDraftCapture(
                preflight: makePreflight([projection(wallet)], keys: keys), keystore: keys
            ).capture()
        ) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .unavailableSecretMaterial)
        }
    }

    private func substrateWallet(
        includeEthereum: Bool = false, cryptoType: CryptoType = .ed25519
    ) throws -> MetaAccountModel {
        let seed = Data(repeating: 0x11, count: 32)
        let publicKey: Data
        switch cryptoType {
        case .sr25519:
            publicKey = try SNKeyFactory().createKeypair(fromSeed: seed).publicKey().rawData()
        case .ed25519:
            publicKey = try EDKeyFactory().derive(fromSeed: seed).publicKey().rawData()
        case .ecdsa:
            publicKey = try SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: seed))
                .publicKey().rawData()
        }
        let ethereumPublicKey = includeEthereum ? try SECKeyFactory()
            .derive(fromPrivateKey: SECPrivateKey(rawData: ethereumPrivateKey))
            .publicKey().rawData() : nil
        return MetaAccountModel(
            metaId: "preflight-wallet", name: "Wallet", substrateAccountId: try publicKey.publicKeyToAccountId(),
            substrateCryptoType: cryptoType.rawValue, substratePublicKey: publicKey,
            ethereumAddress: try ethereumPublicKey?.ethereumAddressFromPublicKey(),
            ethereumPublicKey: ethereumPublicKey, chainAccounts: [], assetKeysOrder: nil,
            canExportEthereumMnemonic: false, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil,
            assetsVisibility: [], hasBackup: false, favouriteChainIds: []
        )
    }

    private func projection(_ wallet: MetaAccountModel) -> MetaAccountSelectionModel {
        MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: false, order: 0,
            displayPreferences: PersistedWalletDisplayPreferences(
                assetFilterOptions: nil, zeroBalanceAssetsHidden: false
            )
        )
    }

    private var ethereumPrivateKey: Data { Data(repeating: 0x01, count: 32) }
    private var substrateSecretKey: Data { Data(repeating: 0x11, count: 64) }

    private func substrateSecretKey(for cryptoType: CryptoType) throws -> Data {
        switch cryptoType {
        case .sr25519:
            return try SNKeyFactory().createKeypair(fromSeed: Data(repeating: 0x11, count: 32))
                .privateKey().rawData()
        case .ed25519:
            return substrateSecretKey
        case .ecdsa:
            return Data(repeating: 0x11, count: 32)
        }
    }

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
