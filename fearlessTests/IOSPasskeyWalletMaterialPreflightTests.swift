@testable import fearless
import CoreData
import CryptoKit
import IrohaCrypto
import SoraKeystore
import struct SSFCrypto.SeedFactory
import SSFModels
import SSFUtils
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

    func testEvmOnlyRootRetainsItsOriginalSignerAndKeystoreExport() throws {
        let wallet = try ethereumOnlyWallet()
        let tag = fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)
        let keys = PreflightKeystore(keys: [tag: ethereumPrivateKey])
        let preflight = makePreflight([projection(wallet)], keys: keys)

        let inventory = try preflight.inspect()
        XCTAssertEqual(inventory.walletCount, 1)
        XCTAssertEqual(inventory.substrateRootCount, 0)
        XCTAssertEqual(inventory.ethereumRootCount, 1)
        XCTAssertEqual(inventory.nativeTonRootCount, 0)

        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: preflight, keystore: keys
        ).capture()
        XCTAssertEqual(draft.wallets.map(\.publicIdentity), [wallet])
        XCTAssertEqual(draft.wallets[0].slots.count, 1)
        XCTAssertEqual(draft.wallets[0].slots[0].role, .ethereumSecret)
        XCTAssertEqual(draft.wallets[0].slots[0].bytes, ethereumPrivateKey)

        let publicKey = try XCTUnwrap(wallet.ethereumPublicKey)
        let address = try XCTUnwrap(wallet.ethereumAddress)
        let account = ChainAccountResponse(
            chainId: "evm-only-export", accountId: address, publicKey: publicKey,
            name: wallet.name, cryptoType: .ecdsa, addressPrefix: 42,
            isEthereumBased: true, isChainAccount: false, walletId: wallet.metaId
        )
        let addressString = "0x" + address.map { String(format: "%02x", $0) }.joined()
        let exported = try KeystoreExportWrapper(keystore: keys).export(
            chainAccount: account, password: "evm-only-test-password", address: addressString,
            metaId: wallet.metaId, accountId: nil, genesisHash: nil
        )
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: exported)
        let restored = try KeystoreExtractor().extractFromDefinition(
            definition, password: "evm-only-test-password"
        )
        XCTAssertEqual(restored.secretKeyData, ethereumPrivateKey)
        XCTAssertEqual(restored.publicKeyData, publicKey)
        XCTAssertEqual(restored.address, addressString)
    }

    func testEvmOnlyRootRejectsUnavailableOrMismatchedMaterial() throws {
        let wallet = try ethereumOnlyWallet()
        let tag = fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId)
        XCTAssertThrowsError(try makePreflight(
            [projection(wallet)], keys: PreflightKeystore()
        ).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .missingSecretMaterial)
        }
        XCTAssertThrowsError(try makePreflight(
            [projection(wallet)], keys: PreflightKeystore(errors: [tag: KeystoreError.unexpectedFail])
        ).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .unavailableSecretMaterial)
        }
        XCTAssertThrowsError(try makePreflight(
            [projection(wallet)], keys: PreflightKeystore(keys: [tag: Data(repeating: 0x02, count: 32)])
        ).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
        let wrongAddress = wallet.replacingEthereumAddress(Data(repeating: 0x44, count: 20))
        XCTAssertThrowsError(try makePreflight(
            [projection(wrongAddress)], keys: PreflightKeystore(keys: [tag: ethereumPrivateKey])
        ).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
        let incomplete = wallet.replacingEthereumPublicKey(nil)
        XCTAssertThrowsError(try makePreflight(
            [projection(incomplete)], keys: PreflightKeystore(keys: [tag: ethereumPrivateKey])
        ).inspect()) {
            XCTAssertEqual($0 as? IOSPasskeyWalletMaterialPreflightError, .incompletePublicIdentity)
        }
    }

    func testEvmOnlyRootDoesNotAdoptUnboundUniversalAccounts() throws {
        let wallet = try ethereumOnlyWallet()
        let entropy = Data(repeating: 0x01, count: 16)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey,
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): entropy
        ])
        XCTAssertNil(try KeychainUniversalWalletMnemonicProvider(keystore: keys)
            .rootMnemonic(for: wallet))
        XCTAssertEqual(
            try UniversalWalletStoredSeedAdopter(keystore: keys)
                .adoptStoredSecret(for: wallet),
            wallet
        )
        XCTAssertTrue(wallet.chainAccounts.isEmpty)
        XCTAssertEqual(
            wallet.backupAddress,
            try XCTUnwrap(wallet.ethereumAddress).toAddress(using: .ethereum)
        )
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

    func testFreshEvmOnlyDraftConvertsToPortableMaterialWithoutLosingHistoricalKeychainBytes() throws {
        let wallet = try ethereumOnlyWallet()
        let strayEntropy = Data(repeating: 0x42, count: 16)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey,
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): strayEntropy
        ])
        let selected = MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true, order: 7,
            displayPreferences: PersistedWalletDisplayPreferences(
                assetFilterOptions: ["historical"], zeroBalanceAssetsHidden: true
            )
        )
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selected], keys: keys), keystore: keys
        ).capture()
        let bytes = try IOSPortableWalletSemanticDraftAdapter.encode(draft)
        var semantic = try IOSPortableWalletSemanticMaterial.decode(bytes)
        defer { semantic.clearSecrets() }

        XCTAssertEqual(semantic.selectedIndex, 0)
        XCTAssertEqual(semantic.wallets[0].sourcePosition, 7)
        XCTAssertEqual(semantic.wallets[0].slots.map(\.role), [2, 7, 7])
        XCTAssertEqual(try semantic.wallets[0].slots[0].value(2), Array(ethereumPrivateKey))
        XCTAssertEqual(try semantic.wallets[0].slots[2].value(20), Array(strayEntropy))
        XCTAssertEqual(try semantic.wallets[0].slots[2].value(17), [1])
        XCTAssertEqual(semantic.wallets[0].metadata.map(\.id), [3, 5, 6, 7, 8, 9])
        XCTAssertEqual(try semantic.wallets[0].metadata.first(where: { $0.id == 8 })?.value, [1])
        XCTAssertEqual(try IOSPortableWalletSemanticMaterial.encode(semantic), bytes)
        XCTAssertEqual(
            try IOSPortableIOSSourceProof.verify(bytes),
            .init(verifiedSources: 1, unprovenSources: 1)
        )
    }

    func testIOSOriginalKeySourceProofRejectsAlteredSignerAndMissingRootSource() throws {
        let wallet = try ethereumOnlyWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey,
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): Data(repeating: 0x42, count: 16)
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        var material = try IOSPortableWalletSemanticMaterial.decode(
            IOSPortableWalletSemanticDraftAdapter.encode(draft)
        )
        defer { material.clearSecrets() }
        let signerIndex = try XCTUnwrap(material.wallets[0].slots.firstIndex { slot in
            slot.role == IOSPortableWalletSemanticMaterial.Role.auxiliarySource &&
                (try? slot.number(IOSPortableWalletSemanticMaterial.FieldID.sourceSlotRole)) == 2
        })
        let sourceIndex = try XCTUnwrap(material.wallets[0].slots[signerIndex].fields.firstIndex {
            $0.id == IOSPortableWalletSemanticMaterial.FieldID.sourceBytes
        })
        material.wallets[0].slots[signerIndex].fields[sourceIndex].value[0] ^= 1
        XCTAssertThrowsError(try IOSPortableIOSSourceProof.verify(
            IOSPortableWalletSemanticMaterial.encode(material)
        ))
        XCTAssertThrowsError(try IOSPortableWalletReceiveInstallPlan.prepare(
            IOSPortableWalletSemanticMaterial.encode(material), approvedSubstrateGenesisIDs: []
        ))

        material.wallets[0].slots.remove(at: signerIndex)
        let remaining = material.wallets[0].slots[1]
        material.wallets[0].slots[1] = .init(role: remaining.role, key: "0000", fields: remaining.fields)
        XCTAssertThrowsError(try IOSPortableIOSSourceProof.verify(
            IOSPortableWalletSemanticMaterial.encode(material)
        ))
    }

    func testIOSOriginalKeySourceProofRejectsDuplicateDestination() throws {
        let wallet = try ethereumOnlyWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        var material = try IOSPortableWalletSemanticMaterial.decode(
            IOSPortableWalletSemanticDraftAdapter.encode(draft)
        )
        defer { material.clearSecrets() }
        let original = material.wallets[0].slots[1]
        let duplicate = IOSPortableWalletSemanticMaterial.Slot(
            role: original.role, key: "0001", fields: original.fields
        )
        material.wallets[0].slots.append(duplicate)
        XCTAssertThrowsError(try IOSPortableIOSSourceProof.verify(
            IOSPortableWalletSemanticMaterial.encode(material)
        ))
    }

    func testIOSOriginalKeySourceProofChecksExplicitlyBoundRootEntropy() throws {
        let wallet = try ethereumOnlyWallet()
        let entropy = Data(repeating: 0x42, count: 16)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey,
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): entropy
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        var material = try IOSPortableWalletSemanticMaterial.decode(
            IOSPortableWalletSemanticDraftAdapter.encode(draft)
        )
        defer { material.clearSecrets() }
        material.wallets[0].slots[0].fields.append(.init(id: 4, value: Array(entropy)))
        material.wallets[0].slots[0].fields.sort { $0.id < $1.id }
        let entropyIndex = try XCTUnwrap(material.wallets[0].slots.firstIndex { slot in
            slot.role == 7 && (try? slot.number(16)) == 4
        })
        let bindingIndex = try XCTUnwrap(material.wallets[0].slots[entropyIndex].fields.firstIndex { $0.id == 17 })
        material.wallets[0].slots[entropyIndex].fields[bindingIndex].value = [3]
        XCTAssertEqual(
            try IOSPortableIOSSourceProof.verify(IOSPortableWalletSemanticMaterial.encode(material)),
            .init(verifiedSources: 2, unprovenSources: 0)
        )
        let sourceIndex = try XCTUnwrap(material.wallets[0].slots[entropyIndex].fields.firstIndex { $0.id == 20 })
        material.wallets[0].slots[entropyIndex].fields[sourceIndex].value[0] ^= 1
        XCTAssertThrowsError(try IOSPortableIOSSourceProof.verify(
            IOSPortableWalletSemanticMaterial.encode(material)
        ))
    }

    func testFreshNativeTonDraftConvertsWithVerifiedPhraseAndPrivateKey() throws {
        let wallet = try LegacyNativeTonFixture.wallet()
        let phrase = Data(LegacyNativeTonFixture.phrase.utf8)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): phrase
        ])
        let selected = MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true, order: 0,
            displayPreferences: PersistedWalletDisplayPreferences(
                assetFilterOptions: nil, zeroBalanceAssetsHidden: false
            )
        )
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selected], keys: keys), keystore: keys
        ).capture()
        var semantic = try IOSPortableWalletSemanticDraftAdapter.snapshot(from: draft)
        defer { semantic.clearSecrets() }

        XCTAssertEqual(semantic.wallets[0].slots.map(\.role), [3, 7])
        let ton = semantic.wallets[0].slots[0]
        XCTAssertEqual(try ton.value(2), Array(try LegacyNativeTonFixture.privateKey()))
        XCTAssertEqual(try ton.value(12), Array(phrase))
        XCTAssertEqual(try ton.value(13), [2])
        XCTAssertEqual(try ton.value(14), [2])
        XCTAssertNoThrow(try IOSPortableWalletSemanticMaterial.encode(semantic))
        XCTAssertEqual(
            try IOSPortableIOSSourceProof.verify(IOSPortableWalletSemanticMaterial.encode(semantic)),
            .init(verifiedSources: 1, unprovenSources: 0)
        )
    }

    func testImportedEVMRootProvesOriginalSignerAndRejectsAlteredSecretOrAddress() throws {
        let wallet = try ethereumOnlyWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        let encoded = try IOSPortableWalletSemanticDraftAdapter.encode(draft)
        XCTAssertEqual(
            try IOSPortableRootSigningProof.verify(encoded),
            .init(wallets: 1, substrateRoots: 0, evmRoots: 1, nativeTonRoots: 0, legacySubstrateRoots: 0)
        )

        var semantic = try IOSPortableWalletSemanticMaterial.decode(encoded)
        defer { semantic.clearSecrets() }
        let keyIndex = try XCTUnwrap(semantic.wallets[0].slots[0].fields.firstIndex { $0.id == 2 })
        semantic.wallets[0].slots[0].fields[keyIndex].value[0] ^= 1
        XCTAssertThrowsError(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ))
        semantic.wallets[0].slots[0].fields[keyIndex].value[0] ^= 1
        let addressIndex = try XCTUnwrap(semantic.wallets[0].slots[0].fields.firstIndex { $0.id == 7 })
        semantic.wallets[0].slots[0].fields[addressIndex].value[0] ^= 1
        XCTAssertThrowsError(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ))
    }

    func testPortableReceivePlanRetainsEvmWalletWithoutAuthorizingInstallation() throws {
        let wallet = try ethereumOnlyWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        let encoded = try IOSPortableWalletSemanticDraftAdapter.encode(draft)

        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertEqual(plan.snapshot.selectedIndex, 0)
        XCTAssertEqual(plan.snapshot.wallets.count, 1)
        XCTAssertEqual(plan.slots, [.init(walletIndex: 0, slotIndex: 0, destination: .evmRoot),
                                    .init(walletIndex: 0, slotIndex: 1, destination: .auxiliarySource)])
        let metadataCount = plan.snapshot.wallets[0].metadata.count
        XCTAssertGreaterThan(metadataCount, 0)
        XCTAssertEqual(plan.blockers, [
            .unprovenAuxiliarySources(1), .unmappedMetadata(metadataCount),
            .transactionalInstallerUnavailable
        ])
        XCTAssertEqual(try IOSPortableWalletSemanticMaterial.encode(plan.snapshot), encoded)
        XCTAssertEqual(String(reflecting: plan), "IOSPortableWalletReceiveInstallPlan.Plan(<redacted>)")
    }

    func testPortableReceivePlanRetainsSelectionAndWatchWalletWithoutWriting() throws {
        let wallet = try ethereumOnlyWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        var original = try IOSPortableWalletSemanticMaterial.decode(
            IOSPortableWalletSemanticDraftAdapter.encode(draft)
        )
        defer { original.clearSecrets() }
        let watch = IOSPortableWalletSemanticMaterial.Wallet(
            portableID: (32 ... 47).map { UInt8($0) }, sourcePosition: 9,
            initialized: false, name: "Watch", metadata: [], slots: [
                .init(role: 8, key: "0000", fields: [
                    .init(id: 7, value: [9]), .init(id: 22, value: [2])
                ])
            ]
        )
        var cohort = IOSPortableWalletSemanticMaterial.Snapshot(
            selectedIndex: 1, wallets: [original.wallets[0], watch]
        )
        defer { cohort.clearSecrets() }
        let encoded = try IOSPortableWalletSemanticMaterial.encode(cohort)

        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertEqual(plan.snapshot.selectedIndex, 1)
        XCTAssertEqual(plan.snapshot.wallets[1].portableID, watch.portableID)
        XCTAssertEqual(plan.snapshot.wallets[1].sourcePosition, 9)
        XCTAssertEqual(plan.slots.last?.destination, .watchIdentity)
        let metadataCount = plan.snapshot.wallets[0].metadata.count
        XCTAssertGreaterThan(metadataCount, 0)
        XCTAssertEqual(plan.blockers, [
            .unprovenAuxiliarySources(1), .unprovenWatchIdentities(1),
            .unmappedMetadata(metadataCount), .unmappedWalletState(1),
            .transactionalInstallerUnavailable
        ])
        XCTAssertEqual(try IOSPortableWalletSemanticMaterial.encode(plan.snapshot), encoded)
    }

    func testPortableReceivePlanRejectsSubstitutedOriginalKey() throws {
        let wallet = try ethereumOnlyWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        var semantic = try IOSPortableWalletSemanticMaterial.decode(
            IOSPortableWalletSemanticDraftAdapter.encode(draft)
        )
        defer { semantic.clearSecrets() }
        let keyIndex = try XCTUnwrap(semantic.wallets[0].slots[0].fields.firstIndex { $0.id == 2 })
        semantic.wallets[0].slots[0].fields[keyIndex].value[0] ^= 1
        XCTAssertThrowsError(try IOSPortableWalletReceiveInstallPlan.prepare(
            IOSPortableWalletSemanticMaterial.encode(semantic), approvedSubstrateGenesisIDs: []
        ))
    }

    func testPortableReceivePlanRequiresApprovedGenesisForChainKeyProof() throws {
        let genesisID = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        let encoded = try importedChainMaterial(cryptoType: .ed25519, chainID: genesisID)

        var unapproved = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { unapproved.clearSecrets() }
        XCTAssertTrue(unapproved.blockers.contains(.unprovenChainAccounts(1)))

        var approved = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: [genesisID]
        )
        defer { approved.clearSecrets() }
        XCTAssertFalse(approved.blockers.contains(.unprovenChainAccounts(1)))
        XCTAssertTrue(approved.blockers.contains(.transactionalInstallerUnavailable))
        XCTAssertEqual(try IOSPortableWalletSemanticMaterial.encode(approved.snapshot), encoded)
    }

    func testPortableReceivePlanDoesNotTreatChainExportSourceAsProvenBySigning() throws {
        let genesisID = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        var material = try IOSPortableWalletSemanticMaterial.decode(
            importedChainMaterial(cryptoType: .ed25519, chainID: genesisID)
        )
        defer { material.clearSecrets() }
        let chainIndex = try XCTUnwrap(material.wallets[0].slots.firstIndex { $0.role == 5 })
        if let seedIndex = material.wallets[0].slots[chainIndex].fields.firstIndex(where: { $0.id == 5 }) {
            material.wallets[0].slots[chainIndex].fields[seedIndex].value = [0x42]
        } else {
            material.wallets[0].slots[chainIndex].fields.append(.init(id: 5, value: [0x42]))
            material.wallets[0].slots[chainIndex].fields.sort { $0.id < $1.id }
        }
        let encoded = try IOSPortableWalletSemanticMaterial.encode(material)

        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: [genesisID]
        )
        defer { plan.clearSecrets() }
        XCTAssertTrue(plan.blockers.contains(.unprovenChainExportMaterial(1)))
        XCTAssertFalse(plan.blockers.contains(.unprovenChainAccounts(1)))
        XCTAssertEqual(try IOSPortableWalletSemanticMaterial.encode(plan.snapshot), encoded)
    }

    func testPortableReceivePlanBlocksUnmappedFavoriteAndMetadata() throws {
        let wallet = try ethereumOnlyWallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId): ethereumPrivateKey
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        var material = try IOSPortableWalletSemanticMaterial.decode(
            IOSPortableWalletSemanticDraftAdapter.encode(draft)
        )
        defer { material.clearSecrets() }
        material.wallets[0].metadata.removeAll { $0.id == 6 }
        material.wallets[0].slots.append(.init(
            role: 6, key: "chain-x", fields: [.init(id: 10, value: [1])]
        ))
        material.wallets[0].slots.sort {
            $0.role < $1.role || $0.role == $1.role && $0.key < $1.key
        }
        let encoded = try IOSPortableWalletSemanticMaterial.encode(material)

        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { plan.clearSecrets() }
        XCTAssertTrue(plan.blockers.contains(.unmappedFavoriteChains(1)))
        XCTAssertTrue(plan.blockers.contains(.unmappedMetadata(material.wallets[0].metadata.count)))
        XCTAssertEqual(try IOSPortableWalletSemanticMaterial.encode(plan.snapshot), encoded)
    }

    func testPortableReceivePlanBlocksUnmappedChainPresentation() throws {
        let genesisID = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        var material = try IOSPortableWalletSemanticMaterial.decode(
            importedChainMaterial(cryptoType: .ed25519, chainID: genesisID)
        )
        defer { material.clearSecrets() }
        let chainIndex = try XCTUnwrap(material.wallets[0].slots.firstIndex { $0.role == 5 })
        let nameIndex = try XCTUnwrap(material.wallets[0].slots[chainIndex].fields.firstIndex { $0.id == 9 })
        let stateIndex = try XCTUnwrap(material.wallets[0].slots[chainIndex].fields.firstIndex { $0.id == 10 })
        material.wallets[0].slots[chainIndex].fields[nameIndex].value = Array("Android label".utf8)
        material.wallets[0].slots[chainIndex].fields[stateIndex].value = [0]
        let encoded = try IOSPortableWalletSemanticMaterial.encode(material)

        var plan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: [genesisID]
        )
        defer { plan.clearSecrets() }
        XCTAssertTrue(plan.blockers.contains(.unmappedChainPresentation(1)))
        XCTAssertFalse(plan.blockers.contains(.unprovenChainAccounts(1)))
        XCTAssertEqual(try IOSPortableWalletSemanticMaterial.encode(plan.snapshot), encoded)
    }

    func testImportedSubstrateRootProvesAllReleasedCryptoTypes() throws {
        for cryptoType in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let wallet = try substrateWallet(cryptoType: cryptoType)
            let keys = PreflightKeystore(keys: [
                fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId):
                    try substrateSecretKey(for: cryptoType)
            ])
            let draft = try IOSPasskeyWalletMaterialDraftCapture(
                preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
            ).capture()
            let encoded = try IOSPortableWalletSemanticDraftAdapter.encode(draft)
            XCTAssertEqual(
                try IOSPortableRootSigningProof.verify(encoded),
                .init(wallets: 1, substrateRoots: 1, evmRoots: 0, nativeTonRoots: 0, legacySubstrateRoots: 0)
            )
        }
    }

    func testImportedRegularSubstrateChainProvesOriginalKeyForAllReleasedCryptoTypes() throws {
        let genesisID = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        for cryptoType in [CryptoType.sr25519, .ed25519, .ecdsa] {
            let encoded = try importedChainMaterial(cryptoType: cryptoType, chainID: genesisID)
            XCTAssertEqual(
                try IOSPortableIOSSourceProof.verify(encoded),
                .init(verifiedSources: 2, unprovenSources: 0)
            )
            XCTAssertEqual(
                try IOSPortableRegularSubstrateChainProof.verify(
                    encoded, approvedSubstrateGenesisIDs: [genesisID]
                ),
                .init(verifiedAccounts: 1, unprovenAccounts: 0)
            )
        }
    }

    func testImportedRegularSubstrateChainRejectsWrongSecretAccountAndCryptoType() throws {
        let genesisID = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        var material = try IOSPortableWalletSemanticMaterial.decode(
            importedChainMaterial(cryptoType: .ed25519, chainID: genesisID)
        )
        defer { material.clearSecrets() }
        material.wallets[0].slots.removeAll { $0.role == 7 }
        let chainIndex = try XCTUnwrap(material.wallets[0].slots.firstIndex { $0.role == 5 })
        let original = material.wallets[0].slots[chainIndex].fields
        for fieldID in [UInt8(2), 7, 8] {
            let index = try XCTUnwrap(material.wallets[0].slots[chainIndex].fields.firstIndex { $0.id == fieldID })
            material.wallets[0].slots[chainIndex].fields[index].value[0] ^= 1
            let encoded = try IOSPortableWalletSemanticMaterial.encode(material)
            XCTAssertThrowsError(try IOSPortableRegularSubstrateChainProof.verify(
                encoded, approvedSubstrateGenesisIDs: [genesisID]
            )) {
                XCTAssertEqual($0 as? IOSPortableRegularSubstrateChainProof.ProofError, .invalidChainIdentity)
            }
            material.wallets[0].slots[chainIndex].fields = original
        }
    }

    func testImportedRegularSubstrateChainLeavesUnapprovedAndNamedSlotsUnproven() throws {
        let genesisID = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        var material = try IOSPortableWalletSemanticMaterial.decode(
            importedChainMaterial(cryptoType: .ed25519, chainID: genesisID)
        )
        defer { material.clearSecrets() }
        // Remove captured auxiliary source bindings to isolate role-5 routing.
        material.wallets[0].slots.removeAll { $0.role == 7 }
        let chainIndex = try XCTUnwrap(material.wallets[0].slots.firstIndex { $0.role == 5 })
        XCTAssertEqual(try IOSPortableRegularSubstrateChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(material), approvedSubstrateGenesisIDs: []
        ), .init(verifiedAccounts: 0, unprovenAccounts: 1))

        material.wallets[0].slots[chainIndex] = .init(
            role: 5, key: UniversalWalletRegistry.solanaMainnet.chainId,
            fields: material.wallets[0].slots[chainIndex].fields
        )
        XCTAssertEqual(try IOSPortableRegularSubstrateChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(material),
            approvedSubstrateGenesisIDs: [genesisID]
        ), .init(verifiedAccounts: 0, unprovenAccounts: 1))
        XCTAssertThrowsError(try IOSPortableRegularSubstrateChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(material),
            approvedSubstrateGenesisIDs: [UniversalWalletRegistry.solanaMainnet.chainId]
        )) {
            XCTAssertEqual(
                $0 as? IOSPortableRegularSubstrateChainProof.ProofError,
                .invalidApprovedChainInventory
            )
        }
    }

    func testImportedRegularSubstrateChainRejectsEvmAccountOnApprovedGenesis() throws {
        let genesisID = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        var material = try IOSPortableWalletSemanticMaterial.decode(
            importedChainMaterial(cryptoType: .ed25519, chainID: genesisID)
        )
        defer { material.clearSecrets() }
        let publicKey = try SECKeyFactory().derive(
            fromPrivateKey: SECPrivateKey(rawData: ethereumPrivateKey)
        ).publicKey().rawData()
        let address = try publicKey.ethereumAddressFromPublicKey()
        material.wallets[0].slots.removeAll { $0.role == 7 }
        let chainIndex = try XCTUnwrap(material.wallets[0].slots.firstIndex { $0.role == 5 })
        let changedFields: [(UInt8, Data)] = [
            (1, publicKey), (2, ethereumPrivateKey), (7, address), (8, Data([3]))
        ]
        for (fieldID, value) in changedFields {
            let index = try XCTUnwrap(material.wallets[0].slots[chainIndex].fields.firstIndex { $0.id == fieldID })
            material.wallets[0].slots[chainIndex].fields[index].value = Array(value)
        }
        XCTAssertThrowsError(try IOSPortableRegularSubstrateChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(material),
            approvedSubstrateGenesisIDs: [genesisID]
        )) {
            XCTAssertEqual($0 as? IOSPortableRegularSubstrateChainProof.ProofError, .invalidChainIdentity)
        }
    }

    func testImportedLegacySubstrateRootChecksSS58IdentityAndSigner() throws {
        let keypair = try SNKeyFactory().createKeypair(fromSeed: Data(repeating: 0x11, count: 32))
        let publicKey = try keypair.publicKey().rawData()
        let secret = try keypair.privateKey().rawData()
        let accountID = try publicKey.publicKeyToAccountId()
        let address = try accountID.toAddress(using: .substrate(42))
        let slot = IOSPortableWalletSemanticMaterial.Slot(role: 4, key: "", fields: [
            .init(id: 1, value: Array(publicKey)), .init(id: 2, value: Array(secret)),
            .init(id: 7, value: Array(address.utf8)), .init(id: 8, value: [1]),
            .init(id: 11, value: [5])
        ])
        var snapshot = IOSPortableWalletSemanticMaterial.Snapshot(selectedIndex: 0, wallets: [
            .init(
                portableID: (1 ... 16).map { UInt8($0) }, sourcePosition: 0, initialized: true,
                name: "Legacy", metadata: [], slots: [slot]
            )
        ])
        defer { snapshot.clearSecrets() }
        XCTAssertEqual(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(snapshot)
        ).legacySubstrateRoots, 1)
        var receivePlan = try IOSPortableWalletReceiveInstallPlan.prepare(
            IOSPortableWalletSemanticMaterial.encode(snapshot), approvedSubstrateGenesisIDs: []
        )
        defer { receivePlan.clearSecrets() }
        XCTAssertTrue(receivePlan.blockers.contains(.unprovenRootExportMaterial(1)))

        let differentPublicKey = try SNKeyFactory()
            .createKeypair(fromSeed: Data(repeating: 0x12, count: 32)).publicKey().rawData()
        let differentAddress = try differentPublicKey.publicKeyToAccountId()
            .toAddress(using: .substrate(42))
        snapshot.wallets[0].slots[0].fields[2].value = Array(differentAddress.utf8)
        XCTAssertThrowsError(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(snapshot)
        ))
    }

    func testImportedNativeTonRootChecksPhraseAndBothAddressEncodings() throws {
        let wallet = try LegacyNativeTonFixture.wallet()
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): Data(LegacyNativeTonFixture.phrase.utf8)
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        let encoded = try IOSPortableWalletSemanticDraftAdapter.encode(draft)
        XCTAssertEqual(try IOSPortableRootSigningProof.verify(encoded).nativeTonRoots, 1)
        var receivePlan = try IOSPortableWalletReceiveInstallPlan.prepare(
            encoded, approvedSubstrateGenesisIDs: []
        )
        defer { receivePlan.clearSecrets() }
        XCTAssertTrue(receivePlan.blockers.contains(.unprovenRootExportMaterial(1)))

        var semantic = try IOSPortableWalletSemanticMaterial.decode(encoded)
        defer { semantic.clearSecrets() }
        let fields = semantic.wallets[0].slots[0].fields
        let addressIndex = try XCTUnwrap(fields.firstIndex { $0.id == 7 })
        let encodingIndex = try XCTUnwrap(fields.firstIndex { $0.id == 14 })
        let phraseIndex = try XCTUnwrap(fields.firstIndex { $0.id == 12 })
        let publicKey = try XCTUnwrap(wallet.legacyTonAccount?.publicKey)
        semantic.wallets[0].slots[0].fields[addressIndex].value = [0] +
            Array(try TonAddressCodec.v4R2AccountHash(publicKey: publicKey))
        semantic.wallets[0].slots[0].fields[encodingIndex].value = [1]
        XCTAssertEqual(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ).nativeTonRoots, 1)
        semantic.wallets[0].slots[0].fields[phraseIndex].value = Array("wrong phrase".utf8)
        XCTAssertThrowsError(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ))

        // Android V3 retains a 32-byte TON private seed and its original
        // mnemonic, while native iOS retains seed||public and field 12.
        var androidFields = fields.filter { $0.id != 12 }
        let privateIndex = try XCTUnwrap(androidFields.firstIndex { $0.id == 2 })
        androidFields[privateIndex].value = Array(try LegacyNativeTonFixture.privateKey().prefix(32))
        androidFields.append(.init(id: 5, value: Array(LegacyNativeTonFixture.phrase.utf8)))
        semantic.wallets[0].slots[0].fields = androidFields.sorted { $0.id < $1.id }
        XCTAssertEqual(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ).nativeTonRoots, 1)
        let seedIndex = try XCTUnwrap(semantic.wallets[0].slots[0].fields.firstIndex { $0.id == 5 })
        semantic.wallets[0].slots[0].fields[seedIndex].value = Array("wrong phrase".utf8)
        XCTAssertThrowsError(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ))
        semantic.wallets[0].slots[0].fields.remove(at: seedIndex)
        XCTAssertThrowsError(try IOSPortableRootSigningProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ))
    }

    func testAndroidProducedNativeTonBytesProveOriginalIOSIdentity() throws {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(
            forResource: "AndroidNativeTonPortableVector", withExtension: "json"
        ))
        let fixture = try JSONDecoder().decode(AndroidNativeTonPortableVector.self, from: Data(contentsOf: url))
        let encoded = try XCTUnwrap(Data(hex: fixture.encodedHex))
        XCTAssertEqual(encoded.count, 604)
        XCTAssertEqual(
            SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined(), fixture.sha256
        )
        XCTAssertEqual(fixture.mnemonic, LegacyNativeTonFixture.phrase)
        XCTAssertEqual(
            fixture.publicKeyHex,
            try LegacyNativeTonFixture.account().publicKey.toHex(includePrefix: false)
        )

        var decoded = try IOSPortableWalletSemanticMaterial.decode(encoded)
        defer { decoded.clearSecrets() }
        XCTAssertEqual(try IOSPortableWalletSemanticMaterial.encode(decoded), encoded)
        let wallet = try XCTUnwrap(decoded.wallets.first)
        XCTAssertEqual(wallet.name, "Wallet 42")
        let ton = try XCTUnwrap(wallet.slots.first {
            $0.role == IOSPortableWalletSemanticMaterial.Role.tonRoot
        })
        XCTAssertEqual(try ton.value(1), Array(try XCTUnwrap(Data(hex: fixture.publicKeyHex))))
        XCTAssertEqual(try ton.value(2), Array(try LegacyNativeTonFixture.privateKey().prefix(32)))
        XCTAssertEqual(try ton.value(5), Array(fixture.mnemonic.utf8))
        XCTAssertEqual(
            try IOSPortableRootSigningProof.verify(encoded),
            .init(wallets: 1, substrateRoots: 0, evmRoots: 0, nativeTonRoots: 1, legacySubstrateRoots: 0)
        )
    }

    func testDraftConversionFailsClosedWithoutSelectionOrSignedRootKey() throws {
        let wallet = try ethereumOnlyWallet()
        let preferences = PersistedWalletDisplayPreferences(
            assetFilterOptions: nil, zeroBalanceAssetsHidden: false
        )
        let noSelection = IOSPasskeyWalletMaterialDraft(wallets: [.init(
            publicIdentity: wallet, isSelected: false, order: 0,
            displayPreferences: preferences,
            slots: [.init(role: .ethereumSecret, chainId: nil, accountId: nil, bytes: ethereumPrivateKey)]
        )])
        XCTAssertThrowsError(try IOSPortableWalletSemanticDraftAdapter.encode(noSelection))

        let missingKey = IOSPasskeyWalletMaterialDraft(wallets: [.init(
            publicIdentity: wallet, isSelected: true, order: 0,
            displayPreferences: preferences, slots: []
        )])
        XCTAssertThrowsError(try IOSPortableWalletSemanticDraftAdapter.encode(missingKey))
    }

    func testAccountScopedTonKeychainSourceIsRetainedWithoutGrantingItSigningAuthority() throws {
        let base = try substrateWallet()
        let chainSecret = Data(repeating: 0x32, count: 32)
        let publicKey = try EDKeyFactory().derive(fromSeed: chainSecret).publicKey().rawData()
        let accountID = try publicKey.publicKeyToAccountId()
        let chain = ChainAccountModel(
            chainId: "historical:chain", accountId: accountID, publicKey: publicKey,
            cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
        )
        let wallet = base.insertingChainAccount(chain)
        let historicalTonBytes = Data(repeating: 0xAC, count: 64)
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey,
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(
                wallet.metaId, accountId: accountID
            ): chainSecret,
            fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(
                wallet.metaId, accountId: accountID
            ): historicalTonBytes
        ])
        let selected = MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true, order: 0,
            displayPreferences: PersistedWalletDisplayPreferences(
                assetFilterOptions: nil, zeroBalanceAssetsHidden: false
            )
        )
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selected], keys: keys), keystore: keys
        ).capture()
        var semantic = try IOSPortableWalletSemanticDraftAdapter.snapshot(from: draft)
        defer { semantic.clearSecrets() }

        XCTAssertEqual(semantic.wallets[0].slots.map(\.role), [1, 5, 7, 7, 7])
        let auxiliary = try XCTUnwrap(semantic.wallets[0].slots.first {
            $0.role == 7 && (try? $0.value(16)) == [3]
        })
        XCTAssertEqual(try auxiliary.value(17), [5])
        XCTAssertEqual(try auxiliary.value(18), Array(chain.chainId.utf8))
        XCTAssertEqual(try auxiliary.value(21), Array(accountID))
        XCTAssertEqual(try auxiliary.value(20), Array(historicalTonBytes))
        XCTAssertNoThrow(try IOSPortableWalletSemanticMaterial.encode(semantic))
    }

    func testRootDerivedBitcoinChainReceivesItsOriginalSignableKey() throws {
        let entropy = Data(repeating: 0x01, count: 16)
        let phrase = try IRMnemonicCreator().mnemonic(fromEntropy: entropy).toString()
        let rootSeed = try SeedFactory().deriveSeed(from: phrase, password: "").seed.miniSeed
        let rootPublicKey = try EDKeyFactory().derive(fromSeed: rootSeed).publicKey().rawData()
        let bitcoin = try BitcoinKeyDerivation.deriveAccount(mnemonic: phrase, network: .mainnet)
        let chain = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: bitcoin.publicKey, publicKey: bitcoin.publicKey,
            cryptoType: CryptoType.ecdsa.rawValue, ethereumBased: false
        )
        let wallet = MetaAccountModel(
            metaId: "derived-bitcoin-wallet", name: "Derived",
            substrateAccountId: try rootPublicKey.publicKeyToAccountId(),
            substrateCryptoType: CryptoType.ed25519.rawValue,
            substratePublicKey: rootPublicKey, ethereumAddress: nil,
            ethereumPublicKey: nil, chainAccounts: [chain], assetKeysOrder: nil,
            canExportEthereumMnemonic: false, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil,
            assetsVisibility: [], hasBackup: false, favouriteChainIds: []
        )
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): rootSeed,
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): entropy,
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(
                wallet.metaId, accountId: bitcoin.publicKey
            ): Data(repeating: 0xAA, count: 32)
        ])
        let selected = MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true, order: 0,
            displayPreferences: PersistedWalletDisplayPreferences(
                assetFilterOptions: nil, zeroBalanceAssetsHidden: false
            )
        )
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selected], keys: keys), keystore: keys
        ).capture()
        var semantic = try IOSPortableWalletSemanticDraftAdapter.snapshot(from: draft)
        defer { semantic.clearSecrets() }

        XCTAssertEqual(semantic.wallets[0].slots.map(\.role), [1, 5, 7, 7, 7])
        let chainSlot = try XCTUnwrap(semantic.wallets[0].slots.first { $0.role == 5 })
        XCTAssertEqual(try chainSlot.value(2), Array(bitcoin.privateKey))
        XCTAssertEqual(try chainSlot.value(1), Array(bitcoin.publicKey))
        XCTAssertNoThrow(try IOSPortableWalletSemanticMaterial.encode(semantic))
        XCTAssertEqual(
            try IOSPortableIOSSourceProof.verify(IOSPortableWalletSemanticMaterial.encode(semantic)),
            .init(verifiedSources: 2, unprovenSources: 1)
        )
        XCTAssertEqual(try IOSPortableNamedChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ), .init(
            bitcoinAccounts: 1, tairaAccounts: 0, solanaAccounts: 0,
            tonAccounts: 0, nexusAccounts: 0
        ))

        let chainIndex = try XCTUnwrap(semantic.wallets[0].slots.firstIndex { $0.role == 5 })
        let keyIndex = try XCTUnwrap(semantic.wallets[0].slots[chainIndex].fields.firstIndex { $0.id == 2 })
        semantic.wallets[0].slots[chainIndex].fields[keyIndex].value[0] ^= 1
        XCTAssertThrowsError(try IOSPortableNamedChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ))
    }

    func testRootDerivedTairaChainRequiresExactMnemonicAndPrivateKey() throws {
        let walletSeed = Data(repeating: 0x01, count: 32)
        let phrase = try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed)
        let rootPublicKey = try EDKeyFactory().derive(fromSeed: walletSeed).publicKey().rawData()
        let taira = try IrohaKeyDerivation.deriveAccount(mnemonic: phrase)
        let chain = ChainAccountModel(
            chainId: UniversalWalletRegistry.taira.chainId,
            accountId: taira.publicKey, publicKey: taira.publicKey,
            cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
        )
        let wallet = MetaAccountModel(
            metaId: "derived-taira-wallet", name: "Derived",
            substrateAccountId: try rootPublicKey.publicKeyToAccountId(),
            substrateCryptoType: CryptoType.ed25519.rawValue,
            substratePublicKey: rootPublicKey, ethereumAddress: nil,
            ethereumPublicKey: nil, chainAccounts: [chain], assetKeysOrder: nil,
            canExportEthereumMnemonic: false, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil,
            assetsVisibility: [], hasBackup: false, favouriteChainIds: []
        )
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): walletSeed,
            fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId): walletSeed,
            fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId):
                Data(UniversalWalletSeedBridge.contract.utf8)
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        var semantic = try IOSPortableWalletSemanticDraftAdapter.snapshot(from: draft)
        defer { semantic.clearSecrets() }
        XCTAssertEqual(
            try IOSPortableIOSSourceProof.verify(IOSPortableWalletSemanticMaterial.encode(semantic)),
            .init(verifiedSources: 3, unprovenSources: 0)
        )
        XCTAssertEqual(try IOSPortableNamedChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ), .init(
            bitcoinAccounts: 0, tairaAccounts: 1, solanaAccounts: 0,
            tonAccounts: 0, nexusAccounts: 0
        ))

        let bridgeIndex = try XCTUnwrap(semantic.wallets[0].slots.firstIndex { slot in
            slot.role == 7 && (try? slot.value(16)) == [9]
        })
        let sourceIndex = try XCTUnwrap(semantic.wallets[0].slots[bridgeIndex].fields.firstIndex { $0.id == 20 })
        semantic.wallets[0].slots[bridgeIndex].fields[sourceIndex].value[0] ^= 1
        XCTAssertThrowsError(try IOSPortableNamedChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ))
    }

    func testRootDerivedSolanaTonAndNexusChainsRejectChangedKeys() throws {
        let walletSeed = Data(repeating: 0x26, count: 32)
        let phrase = try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed)
        let rootPublicKey = try EDKeyFactory().derive(fromSeed: walletSeed).publicKey().rawData()
        let solana = try SolanaKeyDerivation.deriveAccount(mnemonic: phrase)
        let ton = try TonKeyDerivation.deriveAccount(mnemonic: phrase)
        let nexus = try IrohaKeyDerivation.deriveAccount(mnemonic: phrase)
        let chains: [(String, Data)] = [
            (UniversalWalletRegistry.solanaMainnet.chainId, solana.publicKey),
            (UniversalWalletRegistry.solanaDevnet.chainId, solana.publicKey),
            (UniversalWalletRegistry.tonMainnetRegistryEntry.chainId, ton.publicKey),
            (UniversalWalletRegistry.nexus.chainId, nexus.publicKey)
        ]
        let accounts = Set(chains.map { chainID, publicKey in
            ChainAccountModel(
                chainId: chainID, accountId: publicKey, publicKey: publicKey,
                cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
            )
        })
        let wallet = MetaAccountModel(
            metaId: "derived-named-wallet", name: "Derived",
            substrateAccountId: try rootPublicKey.publicKeyToAccountId(),
            substrateCryptoType: CryptoType.ed25519.rawValue,
            substratePublicKey: rootPublicKey, ethereumAddress: nil,
            ethereumPublicKey: nil, chainAccounts: accounts, assetKeysOrder: nil,
            canExportEthereumMnemonic: false, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: nil,
            assetsVisibility: [], hasBackup: false, favouriteChainIds: []
        )
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): walletSeed,
            fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId): walletSeed,
            fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId):
                Data(UniversalWalletSeedBridge.contract.utf8)
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        var semantic = try IOSPortableWalletSemanticDraftAdapter.snapshot(from: draft)
        defer { semantic.clearSecrets() }
        XCTAssertEqual(try IOSPortableNamedChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(semantic)
        ), .init(
            bitcoinAccounts: 0, tairaAccounts: 0, solanaAccounts: 2,
            tonAccounts: 1, nexusAccounts: 1
        ))

        for (chainID, _) in chains {
            var corrupted = semantic
            defer { corrupted.clearSecrets() }
            let chainIndex = try XCTUnwrap(corrupted.wallets[0].slots.firstIndex {
                $0.role == 5 && $0.key == chainID
            })
            let keyIndex = try XCTUnwrap(corrupted.wallets[0].slots[chainIndex].fields.firstIndex { $0.id == 2 })
            corrupted.wallets[0].slots[chainIndex].fields[keyIndex].value[0] ^= 1
            XCTAssertThrowsError(try IOSPortableNamedChainProof.verify(
                IOSPortableWalletSemanticMaterial.encode(corrupted)
            ))
        }

        // A separately imported Solana signer is a valid wallet identity even
        // when it is unrelated to the root mnemonic.
        var independent = semantic
        defer { independent.clearSecrets() }
        let separateKey = Data(repeating: 0x53, count: 32)
        let separatePublicKey = try SolanaKeyDerivation.publicKey(fromPrivateKey: separateKey)
        let solanaIndex = try XCTUnwrap(independent.wallets[0].slots.firstIndex {
            $0.role == 5 && $0.key == UniversalWalletRegistry.solanaMainnet.chainId
        })
        for (fieldID, bytes) in [(UInt8(1), separatePublicKey), (UInt8(2), separateKey),
                                 (UInt8(7), separatePublicKey)] {
            let fieldIndex = try XCTUnwrap(independent.wallets[0].slots[solanaIndex].fields.firstIndex {
                $0.id == fieldID
            })
            independent.wallets[0].slots[solanaIndex].fields[fieldIndex].value = Array(bytes)
        }
        XCTAssertEqual(try IOSPortableNamedChainProof.verify(
            IOSPortableWalletSemanticMaterial.encode(independent)
        ).solanaAccounts, 2)
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

    private func ethereumOnlyWallet() throws -> MetaAccountModel {
        let publicKey = try SECKeyFactory().derive(
            fromPrivateKey: SECPrivateKey(rawData: ethereumPrivateKey)
        ).publicKey().rawData()
        return MetaAccountModel(
            metaId: "evm-only-preflight-wallet", name: "EVM only",
            substrateAccountId: nil, substrateCryptoType: CryptoType.ed25519.rawValue,
            substratePublicKey: nil,
            ethereumAddress: try publicKey.ethereumAddressFromPublicKey(),
            ethereumPublicKey: publicKey,
            chainAccounts: [], assetKeysOrder: nil,
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

    private func selectedProjection(_ wallet: MetaAccountModel) -> MetaAccountSelectionModel {
        MetaAccountSelectionModel(
            identifier: wallet.metaId, wallet: wallet, isSelected: true, order: 0,
            displayPreferences: PersistedWalletDisplayPreferences(
                assetFilterOptions: nil, zeroBalanceAssetsHidden: false
            )
        )
    }

    private func importedChainMaterial(cryptoType: CryptoType, chainID: String) throws -> Data {
        let seed = Data(repeating: 0x32, count: 32)
        let publicKey: Data
        let secret: Data
        switch cryptoType {
        case .sr25519:
            let keypair = try SNKeyFactory().createKeypair(fromSeed: seed)
            publicKey = try keypair.publicKey().rawData()
            secret = try keypair.privateKey().rawData()
        case .ed25519:
            publicKey = try EDKeyFactory().derive(fromSeed: seed).publicKey().rawData()
            secret = seed
        case .ecdsa:
            publicKey = try SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: seed))
                .publicKey().rawData()
            secret = seed
        }
        let accountID = try publicKey.publicKeyToAccountId()
        let wallet = try substrateWallet().insertingChainAccount(ChainAccountModel(
            chainId: chainID, accountId: accountID, publicKey: publicKey,
            cryptoType: cryptoType.rawValue, ethereumBased: false
        ))
        let keys = PreflightKeystore(keys: [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId): substrateSecretKey,
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(
                wallet.metaId, accountId: accountID
            ): secret
        ])
        let draft = try IOSPasskeyWalletMaterialDraftCapture(
            preflight: makePreflight([selectedProjection(wallet)], keys: keys), keystore: keys
        ).capture()
        return try IOSPortableWalletSemanticDraftAdapter.encode(draft)
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

private struct AndroidNativeTonPortableVector: Decodable {
    let mnemonic: String
    let publicKeyHex: String
    let encodedHex: String
    let sha256: String
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

final class IOSPortableWalletMaterialEnvelopeTests: XCTestCase {
    func testPortableSemanticEnvelopeAcceptsEitherOriginOnlyWithPortableMode() throws {
        let vectors: [(String, IOSPortableWalletMaterialEnvelope.Origin)] = [
            ("4650574d4c4530310101030100000002abcd", .android),
            ("4650574d4c4530310102030100000002abcd", .ios)
        ]
        for (hex, origin) in vectors {
            let encoded = data(hex)
            let decoded = try IOSPortableWalletMaterialEnvelope.decode(encoded)
            XCTAssertEqual(decoded.origin, origin)
            XCTAssertEqual(decoded.sourceFormat, .portableSemanticV1)
            XCTAssertEqual(decoded.derivationMode, .portable)
            XCTAssertEqual(decoded.payload, Data([0xAB, 0xCD]))
            XCTAssertEqual(try IOSPortableWalletMaterialEnvelope.encode(decoded), encoded)

            var wrongMode = encoded
            wrongMode[11] = IOSPortableWalletMaterialEnvelope.DerivationMode.localOpaque.rawValue
            XCTAssertThrowsError(try IOSPortableWalletMaterialEnvelope.decode(wrongMode))
        }
        XCTAssertThrowsError(try IOSPortableWalletMaterialEnvelope.encode(.init(
            origin: .ios, sourceFormat: .androidDraftV2,
            derivationMode: .portable, payload: Data([0xAB])
        )))
    }

    func testSyntheticGoldenVectorsMatchAndroidCodecInBothSourceDirections() throws {
        let vectors: [(
            String,
            IOSPortableWalletMaterialEnvelope.Origin,
            IOSPortableWalletMaterialEnvelope.SourceFormat,
            Data
        )] = [
            (
                "4650574d4c453031010101000000000400010203",
                .android,
                .androidDraftV2,
                Data([0, 1, 2, 3])
            ),
            (
                "4650574d4c453031010202000000000210fe",
                .ios,
                .iosKeychainV2Inventory,
                Data([0x10, 0xFE])
            )
        ]
        for (hex, origin, format, payload) in vectors {
            let encoded = data(hex)
            let decoded = try IOSPortableWalletMaterialEnvelope.decode(encoded)
            XCTAssertEqual(decoded.origin, origin)
            XCTAssertEqual(decoded.sourceFormat, format)
            XCTAssertEqual(decoded.derivationMode, .localOpaque)
            XCTAssertEqual(decoded.payload, payload)
            XCTAssertEqual(try IOSPortableWalletMaterialEnvelope.encode(decoded), encoded)
            XCTAssertEqual(
                String(reflecting: decoded),
                "IOSPortableWalletMaterialEnvelope.Record(<redacted>)"
            )
        }
    }

    func testRejectsUnknownSourceDerivationLengthAndTrailingMaterial() throws {
        let valid = data("4650574d4c453031010101000000000400010203")
        var invalid = [Data(valid.dropLast()), valid + Data([0])]
        for (offset, replacement) in [(0, 0), (8, 2), (9, 2), (10, 3),
                                      (11, 1), (12, 0x7F), (15, 0)] {
            var candidate = valid
            candidate[offset] = UInt8(replacement)
            invalid.append(candidate)
        }
        for candidate in invalid {
            XCTAssertThrowsError(try IOSPortableWalletMaterialEnvelope.decode(candidate))
        }
        XCTAssertThrowsError(try IOSPortableWalletMaterialEnvelope.encode(.init(
            origin: .android, sourceFormat: .iosKeychainV2Inventory,
            derivationMode: .localOpaque, payload: Data([1])
        )))
        XCTAssertThrowsError(try IOSPortableWalletMaterialEnvelope.encode(.init(
            origin: .android, sourceFormat: .androidDraftV2,
            derivationMode: .localOpaque, payload: Data(repeating: 0, count: 256 * 1024)
        )))
        XCTAssertThrowsError(try IOSPortableWalletMaterialEnvelope.decode(
            Data(repeating: 0, count: 256 * 1024)
        ))
    }

    private func data(_ hex: String) -> Data {
        Data(stride(from: 0, to: hex.count, by: 2).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: 2)
            return UInt8(hex[start ..< end], radix: 16)!
        })
    }
}
