import XCTest
@testable import fearless
import IrohaCrypto
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFCloudStorage
import SSFModels
import SSFUtils

/// IK-12: backing up an existing wallet to Google Drive works for wallets on many networks.
///
/// The backup file holds one Substrate and one Ethereum slot. The backup screen hands over
/// the wallet's account on every enabled network, which the release candidate rejected as
/// soon as there were more than two. Wallets are built with the app's own import code, the
/// recipe every release since 2.0 used for these key tags; the 4.0.x per-chain layout is
/// rebuilt the way `VerifiedSeedExportReaderTests` documents it. Every upload is restored
/// again through the restore screen's own code and must give back the same accounts.
final class GoogleDriveWalletBackupTests: XCTestCase {
    private let walletPhrase = "bottom drive obey lake curtain smoke basket hold race lonely fit walk"
    private let otherPhrase = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private let substrateRawSeed = "0x" + String(repeating: "1f", count: 32)
    private let ethereumRawSeed = "0x" + String(repeating: "2e", count: 32)
    private let chainRawSeed = "0x" + String(repeating: "3d", count: 32)
    private let tonPhrase = "cluster notice abandon frost gospel boring element situate click mix vague replace imitate garment useful crater resource dose tenant theme foam ancient phrase slight"
    private let backupPassword = "backup password ✓"

    private let kusama = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.kusamaChainId, prefix: 2)
    private let moonbeam = ChainAccountRecordsFixture.chain(
        id: ChainAccountRecordsFixture.moonbeamChainId, ethereumBased: true
    )

    // MARK: - Wallets on many networks

    func testWalletOnManyNetworks_whenBackedUp_thenItsPhraseIsUploadedAndRestoresTheSameAccounts() throws {
        let keystore = InMemoryKeychain()
        var wallet = try importWallet(phrase: walletPhrase, substratePath: "//fearless", keystore: keystore)
        wallet = try importChainAccount(phrase: otherPhrase, chain: kusama, into: wallet, keystore: keystore)
        wallet = try importChainAccount(phrase: otherPhrase, chain: moonbeam, into: wallet, keystore: keystore)
        let accounts = accountsOfBackupScreen(for: wallet)
        // The shape the release candidate rejected: one account per network, far more than two.
        XCTAssertGreaterThan(accounts.count, 20)
        XCTAssertEqual(wallet.chainAccounts.count, 7, "Five app-owned accounts, Kusama and Moonbeam")

        let run = try backUp(wallet, accounts: accounts, keystore: keystore)

        let uploaded = try XCTUnwrap(run.uploaded)
        XCTAssertNil(run.error)
        XCTAssertEqual(run.storedWallet?.hasBackup, true)
        XCTAssertEqual(run.keystoreWrites, 0)
        XCTAssertEqual(run.uploadCount, 1)
        XCTAssertEqual(uploaded.backupAccountType, [.passphrase])
        XCTAssertEqual(uploaded.passphrase, walletPhrase)
        XCTAssertEqual(uploaded.substrateDerivationPath, "//fearless")
        XCTAssertEqual(uploaded.ethDerivationPath, DerivationPathConstants.defaultEthereum)
        XCTAssertEqual(uploaded.cryptoType, "SR25519")
        XCTAssertEqual(uploaded.address, wallet.backupAddress)
        XCTAssertEqual(uploaded.name, wallet.name)
        XCTAssertNil(uploaded.encryptedSeed)
        XCTAssertNil(uploaded.json)

        let restored = try restore(uploaded)
        XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey)
        XCTAssertEqual(restored.ethereumAddress, wallet.ethereumAddress)
        // Bitcoin and Taira are derived from the phrase again; only the per-network imports are not in the file.
        XCTAssertEqual(
            Set(restored.chainAccounts.map(\.publicKey)),
            Set(appOwnedAccounts(of: wallet).map(\.publicKey))
        )
        XCTAssertEqual(
            GoogleDriveBackupContent.accountsNotRestored(from: wallet).map(\.chainId).sorted(),
            [kusama.chainId, moonbeam.chainId].sorted()
        )
        XCTAssertEqual(run.accountsNotRestored, [], "The phrase derives the Bitcoin and Taira accounts again")
    }

    func testRawSeedWalletOnManyNetworks_whenBackedUp_thenBothVerifiedSeedsAreUploadedAndEthereumIsRestored() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(substrateSeed: substrateRawSeed, ethereumSeed: ethereumRawSeed, keystore: keystore)

        let run = try backUp(wallet, accounts: accountsOfBackupScreen(for: wallet), keystore: keystore)

        let uploaded = try XCTUnwrap(run.uploaded)
        XCTAssertNil(run.error)
        XCTAssertEqual(run.storedWallet?.hasBackup, true)
        XCTAssertEqual(run.keystoreWrites, 0)
        XCTAssertEqual(uploaded.backupAccountType, [.seed])
        XCTAssertEqual(uploaded.encryptedSeed?.substrateSeed, substrateRawSeed)
        XCTAssertEqual(uploaded.encryptedSeed?.ethSeed, ethereumRawSeed)
        XCTAssertNil(uploaded.substrateDerivationPath, "An empty path is not stored")
        // iOS before 4.2 restores an Ethereum seed only when a path is present.
        XCTAssertEqual(uploaded.ethDerivationPath, "")
        XCTAssertNil(uploaded.passphrase)

        let restored = try restore(uploaded)
        XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey)
        XCTAssertEqual(restored.ethereumAddress, wallet.ethereumAddress)
        XCTAssertEqual(appOwnedAccounts(of: restored), appOwnedAccounts(of: wallet))
        XCTAssertEqual(run.accountsNotRestored, [], "The seed derives the Bitcoin and Taira accounts again")
    }

    func testPhraseThatNoLongerRecreatesTheWallet_whenBackedUp_thenItIsNotUploadedAndTheVerifiedSeedsAre() throws {
        let keystore = InMemoryKeychain()
        // The first start after import adds the Solana account the stored phrase derives.
        let wallet = try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(
            to: try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore),
            mnemonic: walletPhrase
        )
        let otherEntropy = try IRMnemonicCreator().mnemonic(fromList: otherPhrase).entropy()
        try keystore.saveKey(otherEntropy, with: fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        XCTAssertTrue(availableOptions(for: wallet, keystore: keystore).contains(.mnemonic))

        let run = try backUp(wallet, accounts: accountsOfBackupScreen(for: wallet), keystore: keystore)

        let uploaded = try XCTUnwrap(run.uploaded)
        XCTAssertNil(run.error)
        XCTAssertEqual(run.storedWallet?.hasBackup, true)
        XCTAssertEqual(run.keystoreWrites, 0)
        XCTAssertNil(uploaded.passphrase, "A phrase that restores another address must never be the backup")
        XCTAssertEqual(uploaded.backupAccountType, [.seed])
        let restored = try restore(uploaded)
        XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey)
        XCTAssertEqual(restored.ethereumAddress, wallet.ethereumAddress)
        // The device derived Bitcoin, Solana and Taira from the phrase; the seed restores others,
        // and the backup screen is told which accounts the upload leaves out.
        XCTAssertEqual(appOwnedAccounts(of: wallet).count, 5)
        XCTAssertTrue(Set(appOwnedAccounts(of: restored)).isDisjoint(with: appOwnedAccounts(of: wallet)))
        XCTAssertEqual(run.accountsNotRestored, appOwnedAccounts(of: wallet))
    }

    func testRawSeedWalletWhoseSeedA40xChainImportReplaced_whenBackedUp_thenItsKeyGoesUpAsJsonAndRestores() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(substrateSeed: substrateRawSeed, ethereumSeed: ethereumRawSeed, keystore: keystore)
        let walletWithChainAccount = try importChainAccountAs40x(rawSeed: chainRawSeed, into: wallet, keystore: keystore)

        let run = try backUp(
            walletWithChainAccount, accounts: accountsOfBackupScreen(for: walletWithChainAccount), keystore: keystore
        )

        let uploaded = try XCTUnwrap(run.uploaded)
        XCTAssertNil(run.error)
        XCTAssertEqual(run.storedWallet?.hasBackup, true)
        XCTAssertEqual(run.keystoreWrites, 0)
        XCTAssertEqual(uploaded.backupAccountType, [.json])
        XCTAssertNil(uploaded.encryptedSeed)
        XCTAssertNotNil(uploaded.json?.substrateJson)
        XCTAssertNotNil(uploaded.json?.ethJson)
        let restored = try restore(uploaded)
        XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey)
        XCTAssertEqual(restored.ethereumAddress, wallet.ethereumAddress)
        // JSON files hold no phrase or seed to derive Bitcoin, Solana and Taira from.
        XCTAssertTrue(restored.chainAccounts.isEmpty)
        XCTAssertEqual(appOwnedAccounts(of: walletWithChainAccount).count, 5)
        XCTAssertEqual(run.accountsNotRestored, appOwnedAccounts(of: walletWithChainAccount))
        XCTAssertTrue(
            run.accountsNotRestored?.contains { $0.chainId == UniversalWalletRegistry.solanaMainnet.chainId } == true,
            "SOL on the address this device derived is not in a JSON backup, and the user is told"
        )
    }

    func testTonAccountFromAnotherPhrase_whenBackedUp_thenItsAddressIsReportedAsNotRestored() throws {
        let keystore = InMemoryKeychain()
        let imported = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        let otherKey = try TonKeyDerivation.deriveAccount(mnemonic: otherPhrase).publicKey
        let ton = ChainAccountModel(
            chainId: UniversalWalletRegistry.tonMainnetRegistryEntry.id.uppercased(),
            accountId: otherKey, publicKey: otherKey, cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
        )
        let wallet = imported.replacingChainAccounts(Set(imported.chainAccounts.filter {
            $0.chainId != UniversalWalletRegistry.tonMainnetRegistryEntry.chainId
        }).union([ton]))

        let run = try backUp(wallet, accounts: accountsOfBackupScreen(for: wallet), keystore: keystore)

        XCTAssertEqual(run.uploaded?.passphrase, walletPhrase)
        XCTAssertEqual(run.accountsNotRestored, [ton])
        let address = try XCTUnwrap(UniversalWalletChainAccountSupport.address(for: ton.chainId, publicKey: otherKey))
        XCTAssertEqual(GoogleDriveBackupContent.displayLine(for: ton), "TON: \(address)")
    }

    func testMalformedTonAccount_whenBackedUp_thenMatchingPublicKeyDoesNotHideRecoveryWarning() throws {
        let keystore = InMemoryKeychain()
        let imported = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        let key = try TonKeyDerivation.deriveAccount(mnemonic: walletPhrase).publicKey
        let backup = try XCTUnwrap(backUp(imported, accounts: accountsOfBackupScreen(for: imported), keystore: keystore).uploaded)
        for (accountId, publicKey, cryptoType, ethereumBased) in [
            (Data(repeating: 7, count: 32), key, CryptoType.ed25519.rawValue, false),
            (key, key, CryptoType.sr25519.rawValue, false),
            (key, key, CryptoType.ed25519.rawValue, true),
            (Data([1]), Data([1]), CryptoType.ed25519.rawValue, false)
        ] {
            let ton = ChainAccountModel(
                chainId: UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
                accountId: accountId, publicKey: publicKey, cryptoType: cryptoType, ethereumBased: ethereumBased
            )
            let wallet = imported.replacingChainAccounts([ton])
            XCTAssertEqual(GoogleDriveBackupContent.appOwnedAccountsNotRestored(from: wallet, by: backup), [ton])
        }
        let alias = ChainAccountModel(
            chainId: UniversalWalletRegistry.tonMainnetRegistryEntry.id.uppercased(),
            accountId: key, publicKey: key, cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
        )
        XCTAssertEqual(GoogleDriveBackupContent.appOwnedAccountsNotRestored(
            from: imported.replacingChainAccounts([alias]), by: backup
        ), [])
    }

    // MARK: - Substrate-only wallets

    func testSubstrateOnlyWallet_whenBackedUp_thenItsSeedAloneIsUploadedAndRestores() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(substrateSeed: substrateRawSeed, ethereumSeed: nil, keystore: keystore)
        let accounts = accountsOfBackupScreen(for: wallet)
        XCTAssertTrue(accounts.allSatisfy { !$0.account.isEthereumBased })

        let run = try backUp(wallet, accounts: accounts, keystore: keystore)

        let uploaded = try XCTUnwrap(run.uploaded)
        XCTAssertNil(run.error)
        XCTAssertEqual(run.storedWallet?.hasBackup, true)
        XCTAssertEqual(run.keystoreWrites, 0)
        XCTAssertEqual(uploaded.backupAccountType, [.seed])
        XCTAssertEqual(uploaded.encryptedSeed?.substrateSeed, substrateRawSeed)
        XCTAssertNil(uploaded.encryptedSeed?.ethSeed)
        XCTAssertNil(uploaded.ethDerivationPath)
        let restored = try restore(uploaded)
        XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey)
        XCTAssertNil(restored.ethereumAddress)
        XCTAssertEqual(appOwnedAccounts(of: restored), appOwnedAccounts(of: wallet))
        XCTAssertEqual(run.accountsNotRestored, [])
    }

    func testSubstrateOnlyWalletWithoutSeed_whenBackedUp_thenItsJsonAloneIsUploadedAndRestores() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(substrateSeed: substrateRawSeed, ethereumSeed: nil, keystore: keystore)
        // A wallet imported from a JSON file holds only its secret key.
        try keystore.deleteKey(for: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        XCTAssertEqual(availableOptions(for: wallet, keystore: keystore), [.keystore])

        let run = try backUp(wallet, accounts: accountsOfBackupScreen(for: wallet), keystore: keystore)

        let uploaded = try XCTUnwrap(run.uploaded)
        XCTAssertNil(run.error)
        XCTAssertEqual(run.storedWallet?.hasBackup, true)
        XCTAssertEqual(run.keystoreWrites, 0)
        XCTAssertEqual(uploaded.backupAccountType, [.json])
        XCTAssertNotNil(uploaded.json?.substrateJson)
        XCTAssertNil(uploaded.json?.ethJson)
        let restored = try restore(uploaded)
        XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey)
        // The Bitcoin and Taira accounts this wallet got from its seed do not come back from JSON.
        XCTAssertTrue(restored.chainAccounts.isEmpty)
        XCTAssertEqual(run.accountsNotRestored, appOwnedAccounts(of: wallet))
    }

    // MARK: - Wallets the format cannot hold

    func testNativeTonWallet_whenBackedUp_thenNothingIsUploadedOrChangedAndTheReasonIsTon() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importTonWallet(keystore: keystore)
        let accounts = accountsOfBackupScreen(for: wallet)
        XCTAssertEqual(accounts.map(\.account.legacyTonAddress), [wallet.legacyTonAccount?.address])
        XCTAssertEqual(availableOptions(for: wallet, keystore: keystore), [.mnemonic])
        XCTAssertEqual(GoogleDriveBackupContent.unsupportedReason(for: wallet), .nativeTonWalletNotSupported)

        let run = try backUp(wallet, accounts: accounts, keystore: keystore)

        XCTAssertEqual(run.error as? BackupCreatePasswordError, .nativeTonWalletNotSupported)
        XCTAssertEqual(run.uploadCount, 0)
        XCTAssertEqual(run.storedWallet?.hasBackup, false)
        XCTAssertEqual(run.keystoreWrites, 0)
    }

    func testWalletWithoutSubstrateKey_whenChecked_thenGoogleDriveIsExplainedAsUnavailable() {
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let ethereumOnly = MetaAccountModel(
            metaId: wallet.metaId, name: wallet.name, substrateAccountId: nil, substrateCryptoType: 0,
            substratePublicKey: nil, ethereumAddress: wallet.ethereumAddress, ethereumPublicKey: wallet.ethereumPublicKey,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: true, unusedChainIds: nil,
            selectedCurrency: wallet.selectedCurrency, networkManagmentFilter: nil, assetsVisibility: [],
            hasBackup: false, favouriteChainIds: []
        )

        XCTAssertNil(GoogleDriveBackupContent.unsupportedReason(for: wallet))
        XCTAssertEqual(GoogleDriveBackupContent.unsupportedReason(for: ethereumOnly), .walletWithoutSubstrateAccount)
    }

    func testOnlyPerNetworkAccountsHandedOver_whenBackedUp_thenNothingIsUploadedAndTheMaterialErrorIsShown() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        let perNetwork = ChainAccountInfo(
            chain: kusama,
            account: ChainAccountResponse(
                chainId: kusama.chainId, accountId: Data(repeating: 7, count: 32), publicKey: Data(repeating: 8, count: 32),
                name: wallet.name, cryptoType: .sr25519, addressPrefix: 2, isEthereumBased: false,
                isChainAccount: true, walletId: wallet.metaId
            )
        )

        let run = try backUp(wallet, accounts: [perNetwork], keystore: keystore)

        XCTAssertEqual(run.error as? BackupCreatePasswordError, .incompleteBackupMaterial)
        XCTAssertEqual(run.uploadCount, 0)
        XCTAssertEqual(run.storedWallet?.hasBackup, false)
    }

    // MARK: - Backup screen

    func testBackupScreen_whenTonWalletChoosesGoogleDrive_thenItExplainsAndOffersThePhraseInstead() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importTonWallet(keystore: keystore)
        let screen = BackupScreen(wallet: wallet, chains: networks, options: availableOptions(for: wallet, keystore: keystore))

        screen.tapGoogleDrive()

        XCTAssertTrue(screen.router.createPasswordAccounts.isEmpty)
        let sheet = try XCTUnwrap(screen.router.sheets.last)
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        XCTAssertEqual(sheet.title, R.string.localizable.backupGoogleNotCreatedTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, R.string.localizable.backupGoogleTonUnsupportedMessage(preferredLanguages: languages))
        XCTAssertEqual(
            sheet.actions.map(\.title),
            [R.string.localizable.backupRisksWarningsContinueButton(preferredLanguages: languages)]
        )

        sheet.actions.first?.handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(screen.router.mnemonicExports, 1)
    }

    func testBackupScreen_whenWalletOnManyNetworksChoosesGoogleDrive_thenThePasswordStepOpens() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        let screen = BackupScreen(wallet: wallet, chains: networks, options: availableOptions(for: wallet, keystore: keystore))

        screen.tapGoogleDrive()

        XCTAssertTrue(screen.router.sheets.isEmpty)
        XCTAssertEqual(screen.router.createPasswordAccounts.count, 1)
        XCTAssertNoThrow(try GoogleDriveBackupContent(
            wallet: wallet, accounts: screen.router.createPasswordAccounts.first ?? []
        ))
    }

    func testBackupScreen_whenOnlyBitcoinAndTairaAccountsExist_thenNoPerNetworkWarningIsShown() throws {
        let keystore = InMemoryKeychain()
        let imported = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        let wallet = imported.replacingChainAccounts(Set(imported.chainAccounts.filter {
            $0.chainId == UniversalWalletRegistry.bitcoinMainnet.chainId ||
                $0.chainId == UniversalWalletRegistry.taira.chainId
        }))
        XCTAssertEqual(wallet.chainAccounts.count, 2)
        let screen = BackupScreen(wallet: wallet, chains: networks, options: availableOptions(for: wallet, keystore: keystore))

        screen.presenter.viewDidAppear()

        XCTAssertTrue(screen.router.sheets.isEmpty)
        XCTAssertEqual(screen.interactor.viewDidAppearCount, 1)
    }

    /// Every start adds the Solana account the stored phrase derives
    /// (`ServiceCoordinator.provisionAppOwnedAccountsIfNeeded`); a phrase restore gives it back.
    func testBackupScreen_whenStartupAddedTheSolanaAccount_thenNoPerNetworkWarningIsShown() throws {
        let keystore = InMemoryKeychain()
        let imported = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        let legacy = imported.replacingChainAccounts(Set(imported.chainAccounts.filter {
            $0.chainId == UniversalWalletRegistry.bitcoinMainnet.chainId ||
                $0.chainId == UniversalWalletRegistry.taira.chainId
        }))
        let wallet = try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(
            to: legacy, mnemonic: walletPhrase
        )
        XCTAssertEqual(wallet.chainAccounts.count, 5, "Bitcoin mainnet/testnet, Taira, Solana and BIP39 TON")
        XCTAssertTrue(wallet.chainAccounts.contains { $0.chainId == UniversalWalletRegistry.solanaMainnet.chainId })
        let screen = BackupScreen(
            wallet: wallet,
            chains: networks + [UniversalWalletRegistry.solanaMainnetChainModel],
            options: availableOptions(for: wallet, keystore: keystore)
        )

        screen.presenter.viewDidAppear()

        XCTAssertEqual(GoogleDriveBackupContent.accountsNotRestored(from: wallet), [])
        XCTAssertTrue(screen.router.sheets.isEmpty)
        XCTAssertEqual(screen.interactor.viewDidAppearCount, 1)

        let run = try backUp(wallet, accounts: accountsOfBackupScreen(for: wallet), keystore: keystore)
        XCTAssertEqual(run.uploaded?.passphrase, walletPhrase)
        XCTAssertEqual(run.accountsNotRestored, [], "The phrase derives the Solana account again")
    }

    func testBackupScreen_whenAnAccountWasImportedForOneNetwork_thenTheWarningIsShownFirst() throws {
        let keystore = InMemoryKeychain()
        var wallet = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        wallet = try importChainAccount(phrase: otherPhrase, chain: kusama, into: wallet, keystore: keystore)
        let screen = BackupScreen(wallet: wallet, chains: networks, options: availableOptions(for: wallet, keystore: keystore))

        screen.presenter.viewDidAppear()

        XCTAssertEqual(screen.router.sheets.count, 1)
        XCTAssertEqual(screen.interactor.viewDidAppearCount, 0)
    }

    // MARK: - Password step

    func testPasswordStep_whenTheBackupLeavesBitcoinOut_thenItSaysWhichAccountsBeforeShowingTheWalletBackedUp() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        let bitcoin = try XCTUnwrap(appOwnedAccounts(of: wallet).first {
            $0.chainId == UniversalWalletRegistry.bitcoinMainnet.chainId
        })
        let address = try XCTUnwrap(
            UniversalWalletChainAccountSupport.address(for: bitcoin.chainId, publicKey: bitcoin.publicKey)
        )
        let step = PasswordStep(wallet: wallet)

        step.presenter.didComplete(accountsNotRestored: [bitcoin])

        let sheet = try XCTUnwrap(step.router.sheets.last)
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        XCTAssertEqual(sheet.title, R.string.localizable.backupGooglePartialTitle(preferredLanguages: languages))
        XCTAssertEqual(
            sheet.message,
            R.string.localizable.backupGooglePartialMessage("Bitcoin: \(address)", preferredLanguages: languages)
        )
        XCTAssertTrue(address.hasPrefix("bc1"))
        XCTAssertEqual(step.moduleOutput.completions, 0, "Not shown as backed up while the notice is open")
        XCTAssertEqual(step.router.pops, 0)

        sheet.dismissCompletion?()

        XCTAssertEqual(step.moduleOutput.completions, 1)
        XCTAssertEqual(step.router.pops, 1)
    }

    func testPasswordStep_whenTheBackupLeavesSolanaOut_thenItIsNamedSolanaWithItsBase58Address() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        // A Solana account another phrase derives: no backup of this wallet restores it.
        let otherSolana = try SolanaKeyDerivation.deriveAccount(mnemonic: otherPhrase)
        let solana = ChainAccountModel(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            accountId: otherSolana.publicKey,
            publicKey: otherSolana.publicKey,
            cryptoType: CryptoType.ed25519.rawValue,
            ethereumBased: false
        )
        let step = PasswordStep(wallet: wallet)

        step.presenter.didComplete(accountsNotRestored: [solana])

        let sheet = try XCTUnwrap(step.router.sheets.last)
        let languages = LocalizationManager.shared.selectedLocale.rLanguages
        XCTAssertEqual(
            sheet.message,
            R.string.localizable.backupGooglePartialMessage("Solana: \(otherSolana.address)", preferredLanguages: languages)
        )
        XCTAssertEqual(GoogleDriveBackupContent.displayLine(for: solana), "Solana: \(otherSolana.address)")
    }

    func testPasswordStep_whenTheBackupRestoresEveryAccount_thenTheWalletIsShownBackedUpAtOnce() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(phrase: walletPhrase, substratePath: "", keystore: keystore)
        let step = PasswordStep(wallet: wallet)

        step.presenter.didComplete(accountsNotRestored: [])

        XCTAssertTrue(step.router.sheets.isEmpty)
        XCTAssertEqual(step.moduleOutput.completions, 1)
        XCTAssertEqual(step.router.pops, 1)
    }

    // MARK: - Restoring backups other releases wrote

    /// iOS up to 4.0.x wrote a seed backup without an Ethereum path (`BackupCreatePasswordInteractor`
    /// at tag 4.0.4 passed the Ethereum export's nil path), and restoring dropped the Ethereum key.
    func testSeedBackupWrittenBy40x_whenRestored_thenTheEthereumAccountComesBackToo() throws {
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(substrateSeed: substrateRawSeed, ethereumSeed: ethereumRawSeed, keystore: keystore)
        let shipped = OpenBackupAccount(
            name: wallet.name,
            address: wallet.backupAddress,
            cryptoType: "SR25519",
            substrateDerivationPath: "",
            ethDerivationPath: nil,
            backupAccountType: [.seed],
            encryptedSeed: OpenBackupAccount.Seed(substrateSeed: substrateRawSeed, ethSeed: ethereumRawSeed)
        )

        let restored = try restore(shipped)

        XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey)
        XCTAssertEqual(restored.ethereumAddress, wallet.ethereumAddress)
    }

    /// Golden files written by Android's production backup library (shared_features 1.0.1 and
    /// 1.1.1.44) and by the Android release candidate; synthetic test phrases only.
    func testBackupsWrittenByAndroid_whenRestored_thenEachRestoresTheAddressItIsFiledUnder() throws {
        for fixture in AndroidBackupFixture.restorable {
            let backup = try decodeAndroidBackup(fixture.json, password: fixture.password)

            let restored = try restore(backup, password: fixture.password)

            let address = try XCTUnwrap(restored.substrateAccountId).toAddress(using: .substrate(42))
            XCTAssertEqual(address, fixture.address, fixture.name)
            if let ethereumAddress = fixture.ethereumAddress {
                XCTAssertEqual(restored.ethereumAddress?.toHex(includePrefix: true), ethereumAddress, fixture.name)
            }
        }
    }

    /// A backup keeps the derivation path exactly as typed; the restore must open the same
    /// account as the import did (`docs/substrate-password-vectors.json`, NFKD rule).
    func testNonAsciiPathPassword_whenBackedUp_thenThePathGoesUpVerbatimAndRestoresTheSameAccount() throws {
        for id in ["default24-unicode", "default24-unicode-decomposed-input", "import12-katakana"] {
            let vector = try SubstratePasswordVectors.vector(id)
            let keystore = InMemoryKeychain()
            let wallet = try importWallet(phrase: vector.mnemonic, substratePath: vector.derivationPath, keystore: keystore)
            XCTAssertEqual(
                wallet.substrateAccountId?.toHex(includePrefix: true),
                try vector.account("nfkd", .sr25519).accountId,
                id
            )

            let run = try backUp(wallet, accounts: accountsOfBackupScreen(for: wallet), keystore: keystore)

            let uploaded = try XCTUnwrap(run.uploaded, id)
            XCTAssertEqual(uploaded.backupAccountType, [.passphrase], id)
            // Swift compares strings by canonical equivalence; compare the code points themselves.
            XCTAssertEqual(
                try XCTUnwrap(uploaded.substrateDerivationPath, id).unicodeScalars.map(\.value),
                vector.derivationPath.unicodeScalars.map(\.value),
                id
            )
            let restored = try restore(uploaded)
            XCTAssertEqual(restored.substrateAccountId, wallet.substrateAccountId, id)
            XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey, id)
        }
    }

    func testEthereumOnlyAndroidBackup_whenRestored_thenNothingIsImportedAndTheErrorIsShown() throws {
        let fixture = AndroidBackupFixture.ethereumOnlySeed
        let backup = try decodeAndroidBackup(fixture.json, password: fixture.password)

        let attempt = restoreAttempt(backup, password: fixture.password)

        XCTAssertNil(attempt.operation)
        XCTAssertFalse(attempt.router.messages.isEmpty)
    }
}

// MARK: - Helpers

private extension GoogleDriveWalletBackupTests {
    struct BackupRun {
        let uploaded: OpenBackupAccount?
        let uploadCount: Int
        let error: Error?
        let storedWallet: MetaAccountModel?
        let keystoreWrites: Int
        /// What the backup screen is told restoring the upload does not give back.
        let accountsNotRestored: [ChainAccountModel]?
    }

    /// Substrate networks with their own prefixes, EVM networks, Bitcoin, Taira and TON: what the
    /// backup screen loads for a wallet on every enabled network.
    var networks: [ChainModel] {
        let substrate = (3 ..< 23).map { index in
            ChainAccountRecordsFixture.chain(id: "substrate-\(index)", prefix: UInt16(index))
        }
        let evm = (0 ..< 6).map { index in
            ChainAccountRecordsFixture.chain(id: "evm-\(index)", ethereumBased: true)
        }
        return [ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.polkadotChainId), kusama, moonbeam]
            + substrate + evm + [
                UniversalWalletRegistry.bitcoinMainnetChainModel,
                ChainAccountRecordsFixture.chain(id: UniversalWalletRegistry.taira.chainId),
                ChainAccountRecordsFixture.chain(id: TonChainSelection.mainnetChainId)
            ]
    }

    /// `BackupWalletPresenter.prepareChainAccountInfos`: the wallet's account on every network,
    /// leaving out accounts imported for one network.
    func accountsOfBackupScreen(for wallet: MetaAccountModel) -> [ChainAccountInfo] {
        networks.compactMap { chain in
            guard let account = wallet.fetch(for: chain.accountRequest()), !account.isChainAccount else {
                return nil
            }
            return ChainAccountInfo(chain: chain, account: account)
        }
    }

    /// The wallet's Bitcoin, Solana, BIP39 TON and Taira accounts, in the order the backup screen is told
    /// about them. Every account `UniversalWalletAccountProvisioning` derives belongs here, so
    /// no test can leave one of them out of what a backup is checked against.
    func appOwnedAccounts(of wallet: MetaAccountModel) -> [ChainAccountModel] {
        wallet.chainAccounts
            .filter {
                $0.chainId == UniversalWalletRegistry.bitcoinMainnet.chainId ||
                    $0.chainId == UniversalWalletRegistry.bitcoinTestnet.chainId ||
                    $0.chainId == UniversalWalletRegistry.tonMainnetRegistryEntry.chainId ||
                    $0.chainId == UniversalWalletRegistry.solanaMainnet.chainId ||
                    $0.chainId == UniversalWalletRegistry.taira.chainId
            }
            .sorted { $0.chainId < $1.chainId }
    }

    func availableOptions(for wallet: MetaAccountModel, keystore: KeystoreProtocol) -> [ExportOption] {
        AvailableExportOptionsProvider(keystore: keystore).getAvailableExportOptions(for: wallet, accountId: nil)
    }

    func backUp(
        _ wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        keystore: KeystoreProtocol
    ) throws -> BackupRun {
        // The wallet is stored and selected, as it is when its backup screen is open.
        let facade = UserDataStorageTestFacade()
        try ChainAccountRecordsFixture.save(wallet.replacingIsBackuped(false), in: facade)
        let repository = AnyDataProviderRepository(
            AccountRepositoryFactory(storageFacade: facade).createMetaAccountRepository(for: nil, sortDescriptors: [])
        )

        let countingKeystore = WriteCountingKeystore(keystore)
        let cloudStorage = RecordingCloudStorage()
        let options = availableOptions(for: wallet, keystore: keystore)
        let interactor = BackupCreatePasswordInteractor(
            createPasswordFlow: .backupWallet(flow: .multiple(wallet: wallet, accounts: accounts), options: options),
            accountOperationFactory: MetaAccountOperationFactory(keystore: countingKeystore),
            accountRepository: repository,
            settings: SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue()),
            operationManager: OperationManager(),
            eventCenter: MockEventCenterProtocol(),
            secretManager: MockSecretStoreManagerProtocol(),
            keystore: countingKeystore,
            exportJsonWrapper: KeystoreExportWrapper(keystore: countingKeystore)
        )
        interactor.cloudStorage = cloudStorage
        let output = RecordingBackupOutput(expectation: expectation(description: "backup finished"))
        interactor.setup(with: output)

        interactor.createAndBackupAccount(password: backupPassword)
        wait(for: [output.expectation], timeout: 60)

        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([fetch], waitUntilFinished: true)
        let stored = try XCTUnwrap(fetch.result).get().first { $0.metaId == wallet.metaId }

        XCTAssertTrue(cloudStorage.uploads.allSatisfy { $0.password == backupPassword })
        return BackupRun(
            uploaded: cloudStorage.uploads.last?.account,
            uploadCount: cloudStorage.uploads.count,
            error: output.error,
            storedWallet: stored,
            keystoreWrites: countingKeystore.writeAttempts,
            accountsNotRestored: output.accountsNotRestored
        )
    }

    struct RestoreAttempt {
        let operation: BaseOperation<MetaAccountModel>?
        let router: RestoreRouterStub
        let keystore: InMemoryKeychain
    }

    /// Runs the restore screen's own presenter on a decrypted backup and returns the import it starts.
    func restoreAttempt(_ backup: OpenBackupAccount, password: String) -> RestoreAttempt {
        let keystore = InMemoryKeychain()
        let interactor = RecordingRestoreInteractor(keystore: keystore)
        let router = RestoreRouterStub()
        let view = RestoreViewStub()
        let presenter = BackupPasswordPresenter(
            backupAccounts: [BackupAccount(account: backup, current: true)],
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
        presenter.didLoad(view: view)
        view.passwordViewModel?.inputHandler.changeValue(to: password)

        presenter.didReceiveBackup(result: .success(backup))
        // A backup whose paths carry a ///password starts its import once the funds check of
        // the accounts its words open alone has answered.
        let deadline = Date().addingTimeInterval(5)
        while interactor.importOperation == nil, router.messages.isEmpty, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        return RestoreAttempt(operation: interactor.importOperation, router: router, keystore: keystore)
    }

    func restore(_ backup: OpenBackupAccount, password: String? = nil) throws -> MetaAccountModel {
        let attempt = restoreAttempt(backup, password: password ?? backupPassword)
        let operation = try XCTUnwrap(attempt.operation, "restore did not start: \(attempt.router.messages)")
        let restored = try run(operation)
        return restored
    }

    func importWallet(phrase: String, substratePath: String, keystore: KeystoreProtocol) throws -> MetaAccountModel {
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: phrase),
            username: "Many networks",
            substrateDerivationPath: substratePath,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        return try run(MetaAccountOperationFactory(keystore: keystore).newMetaAccountOperation(
            request: request, isBackuped: false
        ))
    }

    func importWallet(substrateSeed: String, ethereumSeed: String?, keystore: KeystoreProtocol) throws -> MetaAccountModel {
        let request = MetaAccountImportSeedRequest(
            substrateSeed: substrateSeed,
            ethereumSeed: ethereumSeed,
            username: "Raw seed wallet",
            substrateDerivationPath: "",
            ethereumDerivationPath: ethereumSeed == nil ? nil : DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519
        )
        return try run(MetaAccountOperationFactory(keystore: keystore).newMetaAccountOperation(
            request: request, isBackuped: false
        ))
    }

    func importTonWallet(keystore: KeystoreProtocol) throws -> MetaAccountModel {
        try run(LegacyTonAccountImportOperation(
            keystore: keystore, phrase: tonPhrase, username: "TON wallet", isBackuped: false
        ))
    }

    func importChainAccount(
        phrase: String,
        chain: ChainModel,
        into wallet: MetaAccountModel,
        keystore: KeystoreProtocol
    ) throws -> MetaAccountModel {
        try run(MetaAccountOperationFactory(keystore: keystore).importChainAccountOperation(
            request: ChainAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(fromList: phrase),
                username: wallet.name,
                derivationPath: chain.isEthereumBased ? DerivationPathConstants.defaultEthereum : "",
                cryptoType: chain.isEthereumBased ? .ecdsa : .sr25519,
                isEthereum: chain.isEthereumBased,
                meta: wallet,
                chainId: chain.chainId
            )
        ))
    }

    /// Imports a raw-seed Kusama account with the app's own code, then leaves its seed where
    /// 4.0.x left it: under the wallet-level tag only (fearless-iOS tag 4.0.4,
    /// `MetaAccountOperationFactory.importChainAccountOperation`).
    func importChainAccountAs40x(
        rawSeed: String,
        into wallet: MetaAccountModel,
        keystore: KeystoreProtocol
    ) throws -> MetaAccountModel {
        let updated = try run(MetaAccountOperationFactory(keystore: keystore).importChainAccountOperation(
            request: ChainAccountImportSeedRequest(
                seed: rawSeed, username: wallet.name, derivationPath: "", cryptoType: .sr25519,
                isEthereum: false, meta: wallet, chainId: kusama.chainId
            )
        ))
        let chainAccount = try XCTUnwrap(updated.chainAccounts.first { $0.chainId == kusama.chainId })
        let accountTag = fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId, accountId: chainAccount.accountId)
        let seed = try keystore.fetchKey(for: accountTag)
        try keystore.saveKey(seed, with: fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        try keystore.deleteKey(for: accountTag)
        return updated
    }

    func run(_ operation: BaseOperation<MetaAccountModel>) throws -> MetaAccountModel {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let result = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        (operation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        return result
    }

    /// Decrypts a backup file field by field with the backup library's own cipher, as
    /// `CloudStorageService.decodeMobileBackup` does after downloading it.
    func decodeAndroidBackup(_ json: String, password: String) throws -> OpenBackupAccount {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let encryption = EncryptionService()
        func decrypt(_ value: Any?) throws -> String? {
            guard let hex = value as? String, !hex.isEmpty else {
                return nil
            }
            return try encryption.getDecrypted(from: hex, password: password)
        }
        let seed = object["encryptedSeed"] as? [String: Any]
        let files = object["json"] as? [String: Any]

        return OpenBackupAccount(
            name: object["name"] as? String,
            address: try XCTUnwrap(object["address"] as? String),
            passphrase: try decrypt(object["encryptedMnemonicPhrase"]),
            cryptoType: object["cryptoType"] as? String,
            substrateDerivationPath: try decrypt(object["encryptedSubstrateDerivationPath"]),
            ethDerivationPath: try decrypt(object["encryptedEthDerivationPath"]),
            backupAccountType: (object["backupAccountType"] as? [String])?
                .compactMap { OpenBackupAccount.BackupAccountType(rawValue: $0) },
            json: OpenBackupAccount.Json(
                substrateJson: files?["substrateJson"] as? String,
                ethJson: files?["ethJson"] as? String
            ),
            encryptedSeed: OpenBackupAccount.Seed(
                substrateSeed: try decrypt(seed?["substrateSeed"]),
                ethSeed: try decrypt(seed?["ethSeed"])
            )
        )
    }
}

// MARK: - Backup screen

private final class BackupScreen {
    let presenter: BackupWalletPresenter
    let router = BackupWalletRouterStub()
    let interactor = BackupWalletInteractorStub()
    private let view = BackupWalletViewStub()
    private let options: [ExportOption]

    init(wallet: MetaAccountModel, chains: [ChainModel], options: [ExportOption]) {
        self.options = options
        presenter = BackupWalletPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: BackupWalletViewModelFactoryStub()
        )
        presenter.didLoad(view: view)
        presenter.didReceive(chains: chains)
        presenter.didReceive(options: options)
    }

    /// The Google Drive row follows the export rows.
    func tapGoogleDrive() {
        presenter.didSelectRowAt(IndexPath(row: options.count, section: 1))
    }
}

private final class BackupWalletRouterStub: BackupWalletRouterInput {
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var createPasswordAccounts: [[ChainAccountInfo]] = []
    private(set) var mnemonicExports = 0

    func showMnemonicExport(flow _: ExportFlow, from _: ControllerBackedProtocol?) {
        mnemonicExports += 1
    }

    func showKeystoreExport(flow _: ExportFlow, from _: ControllerBackedProtocol?) {}

    func showSeedExport(flow _: ExportFlow, from _: ControllerBackedProtocol?) {}

    func showCreatePassword(
        wallet _: MetaAccountModel,
        accounts: [ChainAccountInfo],
        options _: [ExportOption],
        from _: ControllerBackedProtocol?,
        moduleOutput _: BackupCreatePasswordModuleOutput?
    ) {
        createPasswordAccounts.append(accounts)
    }

    func showWalletDetails(wallet _: MetaAccountModel, from _: ControllerBackedProtocol?) {}

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }
}

private final class BackupWalletInteractorStub: BackupWalletInteractorInput {
    private(set) var viewDidAppearCount = 0

    func setup(with _: BackupWalletInteractorOutput) {}

    func removeBackupFromGoogle() {}

    func viewDidAppear() {
        viewDidAppearCount += 1
    }
}

private final class BackupWalletViewStub: BackupWalletViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func didStartLoading() {}
    func didStopLoading() {}
    func didReceive(viewModel _: ProfileViewModelProtocol) {}
}

private struct BackupWalletViewModelFactoryStub: BackupWalletViewModelFactoryProtocol {
    func createViewModel(
        from wallet: MetaAccountModel,
        locale _: Locale,
        balance _: WalletBalanceInfo?,
        exportOptions _: [ExportOption],
        backupAccounts _: [OpenBackupAccount]?
    ) -> ProfileViewModelProtocol {
        ProfileViewModel(
            profileUserViewModel: WalletsManagmentCellViewModel(
                isSelected: false, walletName: wallet.name, fiatBalance: nil, dayChange: nil, accountScoreViewModel: nil
            ),
            profileOptionViewModel: [],
            logoutViewModel: ProfileOptionViewModel(
                title: "", icon: nil, accessoryTitle: nil, accessoryImage: nil, accessoryType: .arrow, option: nil
            )
        )
    }
}

// MARK: - Password step

private final class PasswordStep {
    let presenter: BackupCreatePasswordPresenter
    let router = BackupCreatePasswordRouterStub()
    let moduleOutput = BackupCreatePasswordModuleOutputStub()
    private let interactor = BackupCreatePasswordInteractorStub()
    private let view = BackupCreatePasswordViewStub()

    init(wallet: MetaAccountModel) {
        presenter = BackupCreatePasswordPresenter(
            logger: Logger.shared,
            flow: .backupWallet(flow: .multiple(wallet: wallet, accounts: []), options: [.mnemonic]),
            moduleOutput: moduleOutput,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
        presenter.didLoad(view: view)
    }
}

private final class BackupCreatePasswordRouterStub: BackupCreatePasswordRouterInput {
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var pops = 0

    func showPinSetup() {}

    func pop(from _: ControllerBackedProtocol?) {
        pops += 1
    }

    func dismiss(from _: ControllerBackedProtocol?) {}

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }
}

private final class BackupCreatePasswordModuleOutputStub: BackupCreatePasswordModuleOutput {
    private(set) var completions = 0

    func backupDidComplete() {
        completions += 1
    }
}

private final class BackupCreatePasswordInteractorStub: BackupCreatePasswordInteractorInput {
    func setup(with _: BackupCreatePasswordInteractorOutput) {}
    func createAndBackupAccount(password _: String) {}
    func hasPincode() -> Bool { true }
}

private final class BackupCreatePasswordViewStub: BackupCreatePasswordViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func didStartLoading() {}
    func didStopLoading() {}
    func setPasswordInputViewModel(_: InputViewModelProtocol) {}
    func setPasswordConfirmationViewModel(_: InputViewModelProtocol) {}
    func setPassword(isMatched _: Bool) {}
}

// MARK: - Backup and restore doubles

/// Google Drive that keeps every upload and reads back exactly what was written.
private final class RecordingCloudStorage: CloudStorageServiceProtocol {
    private let lock = NSLock()
    private var recorded: [(account: OpenBackupAccount, password: String)] = []

    var uploads: [(account: OpenBackupAccount, password: String)] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    var isUserAuthorized: Bool { true }

    func signInIfNeeded() async throws -> CloudStorageAccountState { .authorized }

    func getBackupAccounts() async throws -> [OpenBackupAccount] { [] }

    func saveBackup(account: OpenBackupAccount, password: String) async throws {
        record(account, password)
    }

    func saveBackupAndImport(account: OpenBackupAccount, password: String) async throws -> OpenBackupAccount {
        record(account, password)
        return account
    }

    func importBackup(account _: OpenBackupAccount, password _: String) async throws -> OpenBackupAccount {
        throw CloudStorageServiceError.notFound
    }

    func deleteBackup(account _: OpenBackupAccount) async throws {}

    func disconnect() {}

    private func record(_ account: OpenBackupAccount, _ password: String) {
        lock.lock()
        recorded.append((account, password))
        lock.unlock()
    }
}

private final class RecordingBackupOutput: BackupCreatePasswordInteractorOutput {
    let expectation: XCTestExpectation
    private(set) var error: Error?
    private(set) var accountsNotRestored: [ChainAccountModel]?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didReceive(error: Error) {
        self.error = error
        expectation.fulfill()
    }

    func didComplete(accountsNotRestored: [ChainAccountModel]) {
        self.accountsNotRestored = accountsNotRestored
        expectation.fulfill()
    }
}

/// Forwards to the keystore and counts every attempt to write or delete.
private final class WriteCountingKeystore: KeystoreProtocol {
    private let base: KeystoreProtocol
    private let lock = NSLock()
    private var writes = 0

    var writeAttempts: Int {
        lock.lock()
        defer { lock.unlock() }
        return writes
    }

    init(_ base: KeystoreProtocol) {
        self.base = base
    }

    func addKey(_ key: Data, with identifier: String) throws {
        countWrite()
        try base.addKey(key, with: identifier)
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        countWrite()
        try base.updateKey(key, with: identifier)
    }

    func fetchKey(for identifier: String) throws -> Data {
        try base.fetchKey(for: identifier)
    }

    func checkKey(for identifier: String) throws -> Bool {
        try base.checkKey(for: identifier)
    }

    func deleteKey(for identifier: String) throws {
        countWrite()
        try base.deleteKey(for: identifier)
    }

    private func countWrite() {
        lock.lock()
        writes += 1
        lock.unlock()
    }
}

/// The restore screen's interactor with the import handed back instead of saved.
private final class RecordingRestoreInteractor: BaseAccountImportInteractor, BackupPasswordInteractorInput {
    private(set) var importOperation: BaseOperation<MetaAccountModel>?

    init(keystore: KeystoreProtocol) {
        super.init(
            accountOperationFactory: MetaAccountOperationFactory(keystore: keystore),
            accountRepository: AnyDataProviderRepository(
                AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
                    .createMetaAccountRepository(for: nil, sortDescriptors: [])
            ),
            operationManager: OperationManager(),
            keystoreImportService: KeystoreImportServiceStub(),
            defaultSource: .mnemonic
        )
        // Offline: every account the words alone open stays, as with no network.
        universalWalletFundsProbe = UncheckedFundsProbe()
    }

    override func importAccountUsingOperation(_ operation: BaseOperation<MetaAccountModel>) {
        importOperation = operation
    }

    func setup(with _: BackupPasswordInteractorOutput) {}

    func importBackup(account _: OpenBackupAccount, password _: String) {}

    func signInIfNeeded() {}
}

private struct UncheckedFundsProbe: UniversalWalletFundsProbing {
    func funds(
        of _: UniversalWalletSecret,
        slots _: Set<UniversalWalletSlot>
    ) async -> [UniversalWalletSlot: UniversalWalletFundsReading] {
        [:]
    }
}

private final class RestoreRouterStub: BackupPasswordRouterInput {
    private(set) var messages: [String] = []

    func showWalletImportedScreen(backupAccounts _: [BackupAccount], from _: ControllerBackedProtocol?) {}

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        messages.append([title, message].compactMap { $0 }.joined(separator: ": "))
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        messages.append("\(error)")
        return true
    }
}

private final class RestoreViewStub: BackupPasswordViewInput {
    private(set) var passwordViewModel: InputViewModelProtocol?
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func didStartLoading() {}
    func didStopLoading() {}
    func didReceive(walletName _: String) {}

    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) {
        passwordViewModel = viewModel
    }
}

private final class KeystoreImportServiceStub: KeystoreImportServiceProtocol {
    var definition: KeystoreDefinition? { nil }

    func handle(url _: URL) -> Bool { false }
    func add(observer _: KeystoreImportObserver) {}
    func remove(observer _: KeystoreImportObserver) {}
    func clear() {}
}

// MARK: - Android golden backups

/// `build/safe-upgrade/assets/vectors/android-parity/09-backup`, written by the production-parity
/// oracle with Android's own backup library. Synthetic test phrases only.
private struct AndroidBackupFixture {
    let name: String
    let password: String
    let address: String
    let ethereumAddress: String?
    let json: String

    static let restorable: [AndroidBackupFixture] = [
        AndroidBackupFixture(
            name: "v1-passphrase-sr25519-paths (shared_features 1.1.1.44)",
            password: "fixture-password-1",
            address: "5HdHWkvPFBLd57XgZTVN2WFxaHmrswAmhSrTipd75EKww1af",
            ethereumAddress: nil,
            json: #"{"name":"Passphrase sr25519","address":"5HdHWkvPFBLd57XgZTVN2WFxaHmrswAmhSrTipd75EKww1af","encryptedMnemonicPhrase":"b6f1312e3836ba36e95d7c1a019bb3e39f11bc585aeb098385a307c5cc5fa69b00800000010000000800000016810315af227bb8baed28e26027a83263a68d2db41db5bba876c9debe13f65fa4efcb2ab65ded2c81719cf1e569908376cbf07e20d8af582335325e5413de81689f8b2bfb166593f8c7b85b760aef8c38411e4b8a0f50f7c69d3ce468eef75ed023ca4071208f0cfe4f7ad6f3","encryptedEthDerivationPath":"d13a583a964e1ee2c7798ae4f2bfe9685958518502608432d1dd7d6ad1b585b80080000001000000080000008b5f528a405c2fd697f021d07f01aea8676abd7796026fb4a0cde266439f050fabec86a9e9063bb78d5b0e64ddc95ac25653d4de474fa7","encryptedSubstrateDerivationPath":"2726045da0a0b71804c8401ed5e138ca59e4e397cc7aed00e3e39e6e439ef9ac008000000100000008000000ae75e9252be328f97c6b8c79b211917494aaf73522df75f3d31d7689bb319d72e31f7647840520348cfbe064771205f5816a","cryptoType":"SR25519","backupAccountType":["passphrase"],"encryptedSeed":null,"json":null}"#
        ),
        AndroidBackupFixture(
            name: "v1-passphrase-ed25519-empty-paths (shared_features 1.1.1.44)",
            password: "fixture-password-2",
            address: "5FM25N8HGtacre9TnWQGRK32d1kUp1Gs6Dd7YiYpSPZLjmj6",
            ethereumAddress: nil,
            json: #"{"name":"Passphrase ed25519","address":"5FM25N8HGtacre9TnWQGRK32d1kUp1Gs6Dd7YiYpSPZLjmj6","encryptedMnemonicPhrase":"5d3092c5db0a1f19ef5d3845368755241c0dd0479087df673d719d66e727609200800000010000000800000095d65a0f6b8d805af6e1ed6fc03cea147cf91d0377dc730248245e353805fb6d0af7c6482c72c41a559cfa1676d97a6c4acffd7ffa98e3f299475d4fafe8fc38ff3652d9a3b07dc00a5b3e594b6c8135e4cc7dc8ff1b691e9e6a9502493cfba82a0b7a84ea975dbb4e131015b0782a86bb0f2b14c8a27e09d384384eac6887b4da27494e76","encryptedEthDerivationPath":"9174fa2bd8af3720941fa4c5dfb92cb3461fab479fec256287d5bcb345916eff00800000010000000800000087e4736acb66be078dad3c227cf0fa6d562f558bb8bfcafdb67ddafed9ff34d211967aaddd5af8e8","encryptedSubstrateDerivationPath":"6a89b2b4182a03e02d6383a2a1582d4d09edf80d08ca2599115e4ec580b7650c008000000100000008000000009b5ff17b75b08eb29d6a418baaa9e23138b8c128d25ee1678cb3cecbef36a0c13196cb433eb6fb","cryptoType":"ED25519","backupAccountType":["passphrase"],"encryptedSeed":null,"json":null}"#
        ),
        AndroidBackupFixture(
            name: "v1-passphrase-sr25519-path-password (shared_features 1.1.1.44)",
            password: "パスワード-3",
            address: "5Gbu4xvRzXuGYuuWEh68McU86EZxp9soPGSbUq1mQLMjJG9q",
            ethereumAddress: nil,
            json: #"{"name":"Path password","address":"5Gbu4xvRzXuGYuuWEh68McU86EZxp9soPGSbUq1mQLMjJG9q","encryptedMnemonicPhrase":"63331a65deec671173d0a30a6cce7f229abd8cda9eb614cfdcfee761c2e760850080000001000000080000008fe86c9d42a8e2c2f8d014f282bdd38bb06f4e8afdf0daa6cda46a89dea6f97a9b3fedf0e721a4890999f4fedbdc38eeb5ea0bd759f031dde7abe51c3829c029e73e8ea81b4ae4b7047ade122f028399c6904441347bb652f90e7621b678f3727f2968d08dcf6cf837cb2aebd411f641825b52","encryptedEthDerivationPath":"d05f1bab9e634bdcf99ad644f9197b0a2762d141c29caa624d59082486c440b200800000010000000800000078351e8d30880d8bbf0ffb6b609159b35280f61b519ddb3dd08ca566b16e1b0b1e9974ba3aa3d39e32496d12c8227a53d85cd53b655170","encryptedSubstrateDerivationPath":"964534f75c9097d035a83110dc4347d914651764816fdf4ae256dc8ad516f14800800000010000000800000072146a837cf4406d87aec50b7f158490eaf0fcfab852dd353a5f242539bad37daa05060fa3796a47ce17a1d225910774cc1d83370877e0c688e2","cryptoType":"SR25519","backupAccountType":["passphrase"],"encryptedSeed":null,"json":null}"#
        ),
        AndroidBackupFixture(
            name: "v1-seed-substrate-ed25519 (shared_features 1.1.1.44)",
            password: "fixture-password-4",
            address: "5G15zyNFvx63cvMkpqNu4KrQtQ8FERh2AK4dcAywnFMMf5nB",
            ethereumAddress: nil,
            json: #"{"name":"Seed substrate","address":"5G15zyNFvx63cvMkpqNu4KrQtQ8FERh2AK4dcAywnFMMf5nB","encryptedMnemonicPhrase":null,"encryptedEthDerivationPath":"6d5293bd56ec234b50cf25381aa3a273c5b1238d26ab010362b6f55eb06adc4c00800000010000000800000016e135d85168c5d82f4cc3204d268f40a779eb31997f4f38eb2cfc77f0bd24e77dc6b83e97142259","encryptedSubstrateDerivationPath":"90857f4920f54880632160338625723cea6aa925f93ada4b73157fb63686fa8200800000010000000800000082f9252eb4e1ff6d35a577940dfaa133aebd8226f039828872bdf8f5cd101b2ba4b398b3255a8310ebc87f","cryptoType":"ED25519","backupAccountType":["seed"],"encryptedSeed":{"substrateSeed":"44ed3a6c46498a99fda4c546ee06a5946cee0e9a3aab6ffc5595d500d6c680440080000001000000080000006bfb0f97d7579dbb7131f4a056325d02370098d4ea08c8e6791bcf933af1e8c5830b34aa5931d22cdd0d74699ee6339c244784794a167b0aeb94f13b5df3712ddf7b77f61288d7beda8291c179aa3c3fbe9d0b624e202aedea8c35e257f81346265f0c9bd6d370930770","ethSeed":null},"json":null}"#
        ),
        AndroidBackupFixture(
            name: "v1-seed-both-ecdsa (shared_features 1.1.1.44)",
            password: "fixture-password-6",
            address: "5HMEcggbsk6ViNdeCgEPg5W4GitPNxkwVMLPmJFmZBmnaQn3",
            ethereumAddress: "0x58a57ed9d8d624cbd12e2c467d34787555bb1b25",
            json: #"{"name":"Seed both","address":"5HMEcggbsk6ViNdeCgEPg5W4GitPNxkwVMLPmJFmZBmnaQn3","encryptedMnemonicPhrase":null,"encryptedEthDerivationPath":"971c9c543efccd82adbfa298d1f7ec7519984ab09a2dee9638f7561dedd76392008000000100000008000000dc60ce55d7c79d2233343b8ce6b730f797088c5907d5fad5c56d5bc8651a40411ed7b22e0890416d","encryptedSubstrateDerivationPath":"5ec110ee97fc02ffff4d2daad2c765ffeca4f615bdda07293d25847c0bb252560080000001000000080000004502217c5bd4c2b2a09dbd057deff6166f34ac7846c595dddca479326193c90dcbe2d0603b5e746c","cryptoType":"ECDSA","backupAccountType":["seed"],"encryptedSeed":{"substrateSeed":"b09d3c4dd7300963d5f73975a1fc9fe3c516a7f4953ec5b28ac48562741cebd8008000000100000008000000a779978ad9036835ed3fee65b9f954e5084aa9dc0d07de4c3e3f63201124b9d82719ece5035d1d570f7646f6214c3d317ba32402f28356ebefb0038083a0a5be7e7772e711d65494cd1e41603e53791e764240a1a65f01cbcca966c4725fff075cd9357399fb2e4e67b2","ethSeed":"27ead422887b021140d7ded17ba838abe8444864d4ec849968b1247131fdaccd008000000100000008000000814c1f5ee15d10085df63fc6071c769eae2e7495052e7ff80e08982254bc2f042b8928b2d5c3e149fd7e5ca42e4a9dd7b5337feaf8f11a94562cafbe9d65496d5b4bb3ab5e1f2df4b1a1f5044aef6c4f0cdedce72757bb18ece54c985a48c7fcbe73bcf3eb28ccec1ceb"},"json":null}"#
        ),
        AndroidBackupFixture(
            name: "v0-passphrase (shared_features 1.0.1, no type list)",
            password: "fixture-password-v0",
            address: "5HdHWkvPFBLd57XgZTVN2WFxaHmrswAmhSrTipd75EKww1af",
            ethereumAddress: nil,
            json: #"{"name":"Legacy 2.3.1","address":"5HdHWkvPFBLd57XgZTVN2WFxaHmrswAmhSrTipd75EKww1af","encryptedMnemonicPhrase":"a1ab3dc7db16fb993cadc8d13210985da9c082dbaf85c1b1b343e71bb33434f10080000001000000080000007e520e034280b82ef61b694f97a987e2330e525cd815f18a5dc472af0624730c8e067080e7a440199cd5383c9cf8176d9e3762aeb567b366cc6a1a19e330fb1a4ab253c8ce83b4cc4132361376394e1d0728bc9682b86124d5de6bddee3b1c498a4d35bece4ed6bb36cffd4f35","encryptedEthDerivationPath":"5b68a738663d23142ffc6e4bbd46277cf2239523dc2f298db7abce2f14b5f221008000000100000008000000c45072c34c3b61d13a62b5460332fc11f4d9a14ce5c9edebf01919b48a0fa91dee9a3926ee0e57187c2cab9679d30dc0fe51dbbcfd815c","encryptedSubstrateDerivationPath":"ca28274b0a32ba278894dad8c3cbc2af868666923700c85632ad2e1724b5478e008000000100000008000000a9f4fc3eaf4278f4bc61a5f766769e9808ced5da6591aacc48ca86633b3f2500cef4a8db63617e0fe992f74c50acca290d8d","cryptoType":"SR25519"}"#
        ),
        AndroidBackupFixture(
            name: "v0-passphrase-empty-paths (shared_features 1.0.1, no type list)",
            password: "fixture-password-v0-empty",
            address: "5ErKjJLUyc8TTU2vNKrj5UciogZho2MDawb6nN2KG44aU1aB",
            ethereumAddress: nil,
            json: #"{"name":"Legacy empty paths","address":"5ErKjJLUyc8TTU2vNKrj5UciogZho2MDawb6nN2KG44aU1aB","encryptedMnemonicPhrase":"95094bb14d00347e8cb8c796122cc82f6d11c08fe0b03fa7a3be93ac2b518f29008000000100000008000000918aa2ae2d4ac54b0b4bbd091841ce1564e4d16cde3efc2c9dfa618cc1292867563e2eb5f3b3a18c0be6f51708ccd530dff84717c1bf138b348207efe8dc2cc4db1f47985859a9489e46640fa8364626f1f7d217f4bfa7d1ecf5afc1f7111a7f28f5ec105e70828119568ac7c044138bdbf36e","encryptedEthDerivationPath":"aeb0404aa69c173df63ea5fbde42db270db430a1e335ad58393230847e751023008000000100000008000000164687c470f069c5244017e2ff565ebe06f0799381a2bf523f9e986e19292af12270bcf3936cdfd0","encryptedSubstrateDerivationPath":"6c7f99a10da1343c68cbf5858386f064aff16a9a70e72dd921f57b51e87035af0080000001000000080000003bdd059096b2136327ebb2e27e75e2d1a981107ea002a8d93338a53056559e7f19828e0df5c3aa54","cryptoType":"ED25519"}"#
        ),
        AndroidBackupFixture(
            name: "rc-written-v1-verified (Android release candidate, read by 4.2.0)",
            password: "rc-written-password",
            address: "5FM25N8HGtacre9TnWQGRK32d1kUp1Gs6Dd7YiYpSPZLjmj6",
            ethereumAddress: "0x9858effd232b4033e47d90003d41ec34ecaeda94",
            json: #"{"name":"Written by the RC","address":"5FM25N8HGtacre9TnWQGRK32d1kUp1Gs6Dd7YiYpSPZLjmj6","encryptedMnemonicPhrase":"ac380255aa86c8e767e2a5c32fda218341f9feb5748d659a189bfe755f76e4dd008000000100000008000000dabc1fe046e555c5cb6080a27f3b1f843583e18755252ba9750a3554bf7cce7446a3062cd690566c74da511944de958f22126032883cd2d13b9aa1076fabe38474d879191b8c3b92f8f9c0c184e7edf2530dc52be8271be4315a2bcfc7bd6c72809401ccbff36b0d6b1747ca3f7cd6633462db124af71aa01c95ad3807463218547ba2e6c7","encryptedEthDerivationPath":"3798aec70431d27b8a756c12fb827b0afc5ccd24132dc17e2e0fb0dd575688bd008000000100000008000000df3df0ef1bcdf88d0e6f3df01bf0d670c4c72c6acbb053590b6edf7c6d2cf27c98d6f9e843621d8a48ca5a9a441eb061d5b1c5893bec50","encryptedSubstrateDerivationPath":"067692f186e9501d29ecad435a9170da32974fdba7edc019bf0210de56c9253400800000010000000800000003dc82d816ca1f71717e2a3f5786a60662798fa64daf1847e372bfc8fecd66161ac854ab2a1083c7","cryptoType":"ED25519","backupAccountType":["passphrase","seed","json"],"encryptedSeed":{"substrateSeed":"dfa6859472dc5e90bfe6d448a92ff464553d796b625e4633f606dd960a3b35e5008000000100000008000000fe966e3465582829ab8261c258cb69ca997b86ee3949db721e307aeb42685c7963cf20ab44ad9331d19d54f112cf225012da76471abf688e94f5179292bd1b843520983a33dd9711ff182d3734a57ab70c0819b813b27037fdbb3edfbf2b6047c5d6abe0ec4591a65039","ethSeed":"e3035536307764bd1f24c3a08d1a72ccc59d1acb83eef5c8f04a233de5cf4c00008000000100000008000000668726ccd18764b46373338accdd72bb7091b1039a121cb67c2359d2da924d0a4b428cce2354c8d3f20ca8b8b79bcebd97445f688b66425775de85eaec9db2f72aee4d7f8d2861b2afc09c4b770735f60c55e63ed5a578657b95096390ceb5c07bc57e88b0a8ce35ee2a"},"json":{"substrateJson":"{\"encoded\":\"synthetic-fixture-not-a-keystore\",\"encoding\":{\"content\":[\"pkcs8\",\"ed25519\"],\"type\":[\"scrypt\",\"xsalsa20-poly1305\"],\"version\":\"3\"},\"address\":\"5FM25N8HGtacre9TnWQGRK32d1kUp1Gs6Dd7YiYpSPZLjmj6\",\"meta\":{\"name\":\"fixture\"}}","ethJson":"{\"encoded\":\"synthetic-fixture-not-a-keystore\",\"encoding\":{\"content\":[\"pkcs8\",\"ethereum\"],\"type\":[\"scrypt\",\"xsalsa20-poly1305\"],\"version\":\"3\"},\"address\":\"0x9858effd232b4033e47d90003d41ec34ecaeda94\",\"meta\":{\"name\":\"fixture\"}}"}}"#
        )
    ]

    static let ethereumOnlySeed = AndroidBackupFixture(
        name: "v1-seed-ethereum-only (shared_features 1.1.1.44)",
        password: "fixture-password-5",
        address: "5DyFsM2F6kLfdKM5XuGS5r8784cziF5w9nhdPPHks1JYWu2N",
        ethereumAddress: "0x9858effd232b4033e47d90003d41ec34ecaeda94",
        json: #"{"name":"Seed ethereum","address":"5DyFsM2F6kLfdKM5XuGS5r8784cziF5w9nhdPPHks1JYWu2N","encryptedMnemonicPhrase":null,"encryptedEthDerivationPath":null,"encryptedSubstrateDerivationPath":null,"cryptoType":"ECDSA","backupAccountType":["seed"],"encryptedSeed":{"substrateSeed":null,"ethSeed":"cf6d15f22f98d64f62a73457311c9ba86739f5895b4bc8e66dc5481e30da31dd0080000001000000080000002f3381dc2e545e389f5e08f6dc5baedad76fae3c661edd2e1aeb5e4b27b98c9fd3f779c89f35285f186a469638388479b090483ec7a36068a6409fd0d65b74f2b953bfd492a5809119eef6d56b938f6c39a3b51119d63a9126d46af58b8b67824880e5a21ab4a698f8da"},"json":null}"#
    )
}

/// Backing a stored wallet up to Google Drive reads and uploads its recovery phrase, so the
/// password screen only opens after the PIN or biometrics, like the other exports.
final class BackupWalletRouterAuthorizationTests: XCTestCase {
    func testGoogleBackup_asksForAuthorizationBeforeOpeningThePasswordScreen() throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let root = HostController()
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        let router = BackupWalletRouter()
        router.showCreatePassword(
            wallet: AccountGenerator.generateMetaAccount(),
            accounts: [],
            options: [],
            from: root,
            moduleOutput: nil
        )

        XCTAssertEqual(navigation.viewControllers.count, 1, "The password screen must wait for authorization")
        XCTAssertTrue(navigation.presentedViewController is PinSetupViewProtocol)
        navigation.dismiss(animated: false)
    }

    func testBackupPasswordPredicate_requiresEightCharacters() {
        XCTAssertFalse(NSPredicate.backupPassword.evaluate(with: ""))
        XCTAssertFalse(NSPredicate.backupPassword.evaluate(with: "1234567"))
        XCTAssertFalse(NSPredicate.backupPassword.evaluate(with: "パスワード12"))
        XCTAssertTrue(NSPredicate.backupPassword.evaluate(with: "12345678"))
        XCTAssertTrue(NSPredicate.backupPassword.evaluate(with: "backup password ✓"))
        XCTAssertTrue(NSPredicate.backupPassword.evaluate(with: "パスワード1234"))
        XCTAssertTrue(NSPredicate.backupPassword.evaluate(with: "line\nbreak"))
    }
}

private final class HostController: UIViewController, ControllerBackedProtocol {}
