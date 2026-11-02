@testable import fearless
import CommonCrypto
import CryptoKit
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCloudStorage
import SSFModels
import XCTest

/// Design A: a wallet with a `///password` derives Bitcoin, Solana, TON and Taira with it as the
/// BIP39 passphrase, and keeps every address an earlier release showed until it is emptied.
final class UniversalWalletPasswordTests: XCTestCase {
    private static let password = "TREZOR"
    private static let substratePath = "//polkadot///TREZOR"

    private var defaultsSuite = ""
    private var defaults: UserDefaults!
    private var watched: UniversalWalletWatchedAccountsStore!

    override func setUp() {
        super.setUp()
        defaultsSuite = "UniversalWalletPasswordTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuite)
        watched = UniversalWalletWatchedAccountsStore(userDefaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuite)
        super.tearDown()
    }

    // MARK: - Shared vectors

    func testPassphraseVectorsDeriveTheIndependentlyComputedAccounts() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(fixture.version, 1)
        XCTAssertEqual(fixture.vectors.map(\.id), ["import12-trezor", "default24-unicode"])
        XCTAssertEqual(fixture.vectors.map(\.wordCount), [12, 24])

        for vector in fixture.vectors {
            XCTAssertEqual(
                hex(Data(vector.passphrase.decomposedStringWithCompatibilityMapping.utf8)),
                vector.passphraseNfkdUtf8Hex
            )
            for (network, key) in [(BitcoinKeyDerivation.Network.mainnet, "mainnet"), (.testnet, "testnet")] {
                let expected = try XCTUnwrap(vector.expected.bitcoin[key])
                let account = try BitcoinKeyDerivation.deriveAccount(
                    mnemonic: vector.mnemonic, passphrase: vector.passphrase, network: network
                )
                XCTAssertEqual(account.accountPath, expected.accountPath)
                XCTAssertEqual(account.firstReceivePath, expected.firstReceivePath)
                XCTAssertEqual(account.accountXpub, expected.accountXpub)
                XCTAssertEqual(account.firstReceiveAddress, expected.firstReceiveAddress)
            }

            let solana = try SolanaKeyDerivation.deriveAccount(mnemonic: vector.mnemonic, passphrase: vector.passphrase)
            XCTAssertEqual(solana.derivationPath, vector.expected.solana.derivationPath)
            XCTAssertEqual(hex(solana.publicKey), vector.expected.solana.publicKeyHex)
            XCTAssertEqual(solana.address, vector.expected.solana.address)

            let ton = try TonKeyDerivation.deriveAccount(mnemonic: vector.mnemonic, passphrase: vector.passphrase)
            XCTAssertEqual(ton.derivationPath, vector.expected.ton.derivationPath)
            XCTAssertEqual(ton.publicKeyHex, vector.expected.ton.publicKeyHex)
            XCTAssertEqual(ton.addressBounceable, vector.expected.ton.addressBounceable)
            XCTAssertEqual(ton.addressNonBounceable, vector.expected.ton.addressNonBounceable)
            XCTAssertEqual(ton.testnetNonBounceable, vector.expected.ton.testnetNonBounceable)

            for network in [vector.expected.iroha.taira, vector.expected.iroha.nexus] {
                let iroha = try IrohaKeyDerivation.deriveAddress(
                    mnemonic: vector.mnemonic,
                    passphrase: vector.passphrase,
                    chainDiscriminant: network.chainDiscriminant
                )
                XCTAssertEqual(iroha.account.derivationPath, vector.expected.iroha.derivationPath)
                XCTAssertEqual(iroha.account.publicKeyHex, network.publicKeyHex)
                XCTAssertEqual(iroha.account.canonicalHex, network.canonicalHex)
                XCTAssertEqual(iroha.i105, network.i105)
            }

            // negativeCases.password-ignored: the words alone open other accounts.
            XCTAssertNotEqual(
                try BitcoinKeyDerivation.deriveAccount(mnemonic: vector.mnemonic).firstReceiveAddress,
                vector.expected.bitcoin["mainnet"]?.firstReceiveAddress
            )
            XCTAssertNotEqual(try SolanaKeyDerivation.deriveAccount(mnemonic: vector.mnemonic).address, solana.address)
            XCTAssertNotEqual(try TonKeyDerivation.deriveAccount(mnemonic: vector.mnemonic).publicKeyHex, ton.publicKeyHex)
        }
        XCTAssertEqual(
            fixture.negativeCases.map(\.id),
            ["password-ignored", "passphrase-not-normalised", "path-is-not-password"]
        )
    }

    func testPassphraseIsNfkdNormalisedAsBip39Specifies() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first { $0.id == "default24-unicode" })
        let composed = vector.passphrase.precomposedStringWithCanonicalMapping
        let decomposed = vector.passphrase.decomposedStringWithCompatibilityMapping
        XCTAssertNotEqual(Data(composed.utf8), Data(decomposed.utf8))

        for passphrase in [composed, decomposed] {
            XCTAssertEqual(
                try SolanaKeyDerivation.deriveAccount(mnemonic: vector.mnemonic, passphrase: passphrase).address,
                vector.expected.solana.address
            )
            XCTAssertEqual(
                try BitcoinKeyDerivation.deriveAccount(mnemonic: vector.mnemonic, passphrase: passphrase)
                    .firstReceiveAddress,
                vector.expected.bitcoin["mainnet"]?.firstReceiveAddress
            )
        }

        // negativeCases.passphrase-not-normalised: the composed bytes are another passphrase.
        let unnormalisedSeed = try pbkdf2Seed(mnemonic: vector.mnemonic, salt: "mnemonic" + composed)
        let unnormalised = try SolanaKeyDerivation.publicKey(
            fromPrivateKey: SolanaKeyDerivation.derivePrivateKey(seed: unnormalisedSeed).privateKey
        )
        XCTAssertNotEqual(hex(unnormalised), vector.expected.solana.publicKeyHex)
    }

    func testPassphraseSourcesResolveFromTheSubstrateThenTheEthereumPath() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(fixture.passphraseSources.count, 6)

        for source in fixture.passphraseSources {
            let ethereumPath = source.ethereumPathPassword.map {
                "\(DerivationPathConstants.defaultEthereum)///\($0)"
            } ?? DerivationPathConstants.defaultEthereum
            XCTAssertEqual(
                UniversalWalletPassphrase.resolve(
                    substrateDerivationPath: source.substrateDerivationPath,
                    ethereumDerivationPath: ethereumPath
                ),
                source.passphrase,
                source.id
            )
            let request = MetaAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(fromList: fixture.vectors[0].mnemonic),
                username: source.id,
                substrateDerivationPath: source.substrateDerivationPath,
                ethereumDerivationPath: ethereumPath,
                cryptoType: .sr25519,
                defaultChainId: nil
            )
            XCTAssertEqual(request.universalWalletPassphrase, source.passphrase, source.id)
        }
        XCTAssertEqual(UniversalWalletPassphrase.resolve(substrateDerivationPath: nil, ethereumDerivationPath: nil), "")
    }

    // MARK: - Create and import

    func testCreatedPasswordWalletUsesThePasswordForEveryUniversalAccount() throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(vector.mnemonic, enrollment: .generated, keystore: keystore)

        XCTAssertEqual(try slotKeys(in: wallet), try passwordKeys(vector))
        XCTAssertEqual(
            UniversalWalletAccountAddressResolver.address(for: UniversalWalletRegistry.bitcoinMainnetChainModel, wallet: wallet),
            vector.expected.bitcoin["mainnet"]?.firstReceiveAddress
        )
        XCTAssertEqual(
            UniversalWalletAccountAddressResolver.address(for: UniversalWalletRegistry.tairaChainModel, wallet: wallet),
            vector.expected.iroha.taira.i105
        )

        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        for chain in signingChains {
            let secret = try XCTUnwrap(provider.secret(for: wallet, chain: chain))
            XCTAssertEqual(secret, UniversalWalletSecret(mnemonic: vector.mnemonic, passphrase: Self.password))
        }
        XCTAssertEqual(
            UniversalWalletPasswordSwitcher(mnemonicProvider: provider, watchedAccounts: watched)
                .noPasswordAccounts(in: wallet),
            []
        )
        XCTAssertEqual(watched.watchedSlots(in: wallet.metaId), [], "Fresh words leave no old account")
    }

    func testImportKeepsFundedAndUncheckedNoPasswordAccountsAndProtectsTheRest() throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let funds: [UniversalWalletSlot: UniversalWalletFundsState] = [
            .bitcoinMainnet: .funded, .bitcoinTestnet: .empty, .solana: .unknown, .ton: .empty, .taira: .empty
        ]
        let wallet = try importWallet(vector.mnemonic, enrollment: .probed(funds), keystore: keystore)
        let keys = try slotKeys(in: wallet)
        let wordsOnly = try noPasswordKeys(vector.mnemonic)
        let protected = try passwordKeys(vector)

        XCTAssertEqual(keys[.bitcoinMainnet], wordsOnly[.bitcoinMainnet])
        XCTAssertEqual(keys[.solana], wordsOnly[.solana])
        XCTAssertEqual(keys[.bitcoinTestnet], protected[.bitcoinTestnet])
        XCTAssertEqual(keys[.ton], protected[.ton])
        XCTAssertEqual(keys[.taira], protected[.taira])

        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        XCTAssertEqual(
            try provider.secret(for: wallet, chain: UniversalWalletRegistry.bitcoinMainnetChainModel)?.passphrase, ""
        )
        XCTAssertEqual(try provider.secret(for: wallet, chain: UniversalWalletRegistry.solanaMainnetChainModel)?.passphrase, "")
        XCTAssertEqual(
            try provider.secret(for: wallet, chain: UniversalWalletRegistry.tairaChainModel)?.passphrase, Self.password
        )
    }

    func testImportWithoutAFundsCheckKeepsEveryNoPasswordAccount() throws {
        let vector = try trezorVector()
        let wallet = try importWallet(vector.mnemonic, enrollment: .unchecked, keystore: InMemoryKeychain())
        XCTAssertEqual(try slotKeys(in: wallet), try noPasswordKeys(vector.mnemonic))
    }

    func testWalletWithoutAPasswordKeepsTheV2Accounts() throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(
            vector.mnemonic, substratePath: "//polkadot", enrollment: .generated, keystore: keystore
        )
        XCTAssertEqual(try slotKeys(in: wallet), try noPasswordKeys(vector.mnemonic))
        XCTAssertEqual(
            try KeychainUniversalWalletMnemonicProvider(keystore: keystore).rootSecret(for: wallet)?.passphrase, ""
        )
    }

    func testPasswordImportChecksNoPasswordFundsBeforeSaving() throws {
        let vector = try trezorVector()
        let factory = RecordingOperationFactory()
        let probe = StaticFundsProbe(funds: [
            .bitcoinMainnet: .funded, .bitcoinTestnet: .empty, .solana: .unknown, .ton: .empty, .taira: .empty
        ])
        let interactor = makeImportInteractor(factory: factory)
        interactor.universalWalletFundsProbe = probe
        let requested = expectation(description: "Import request built after the funds check")
        factory.onMnemonicRequest = { _ in requested.fulfill() }

        interactor.importMetaAccount(request: try importRequest(vector.mnemonic, substratePath: Self.substratePath))
        wait(for: [requested], timeout: 10)

        XCTAssertEqual(probe.checkedMnemonics, [vector.mnemonic])
        XCTAssertEqual(probe.checkedSlots, [Set(UniversalWalletSlot.allCases)])
        XCTAssertEqual(
            factory.mnemonicRequests.first?.universalWalletEnrollment,
            .imported(keepingNoPassword: [.bitcoinMainnet, .solana])
        )
    }

    func testImportWithoutAPasswordNeverChecksFunds() throws {
        let vector = try trezorVector()
        let factory = RecordingOperationFactory()
        let probe = StaticFundsProbe(funds: [:])
        let interactor = makeImportInteractor(factory: factory)
        interactor.universalWalletFundsProbe = probe

        interactor.importMetaAccount(request: try importRequest(vector.mnemonic, substratePath: "//polkadot"))

        XCTAssertEqual(factory.mnemonicRequests.count, 1)
        XCTAssertEqual(factory.mnemonicRequests.first?.universalWalletEnrollment, .unchecked)
        XCTAssertTrue(probe.checkedMnemonics.isEmpty)
    }

    func testEnrollmentKeepsEverythingAFundsCheckDidNotFindEmpty() {
        XCTAssertEqual(
            UniversalWalletPasswordEnrollment.probed([.ton: .empty, .taira: .funded]),
            .imported(keepingNoPassword: [.bitcoinMainnet, .bitcoinTestnet, .solana, .taira])
        )
        XCTAssertEqual(UniversalWalletPasswordEnrollment.generated.passphrase(for: .ton, password: "p"), "p")
        XCTAssertEqual(UniversalWalletPasswordEnrollment.unchecked.passphrase(for: .ton, password: "p"), "")
    }

    // MARK: - Restore of a wallet an earlier release created

    /// Seeds the keychain and wallet the way 4.0.4-4.1.x stored a wallet imported with
    /// `//polkadot///TREZOR`: root entropy, both paths, and Bitcoin, TON and Taira derived from the
    /// words alone. Those releases created no Solana account.
    func testEarlierReleaseWalletKeepsEveryNoPasswordAddressThroughUpgradeAndStillSigns() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let earlier = try seedEarlierReleaseWallet(vector.mnemonic, keystore: keystore)
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        let root = try XCTUnwrap(provider.rootSecret(for: earlier))
        XCTAssertEqual(root, UniversalWalletSecret(mnemonic: vector.mnemonic, passphrase: Self.password))

        for solanaFunds in [UniversalWalletFundsState.funded, .unknown, .empty] {
            let probe = StaticFundsProbe(funds: [.solana: solanaFunds])
            let upgraded = try await UniversalWalletAccountProvisioning.enrollingMissingAccounts(
                in: earlier, root: root, probe: probe, watchedAccounts: watched
            )
            let persisted = try JSONDecoder().decode(MetaAccountModel.self, from: JSONEncoder().encode(upgraded))

            XCTAssertTrue(earlier.chainAccounts.isSubset(of: persisted.chainAccounts), "\(solanaFunds)")
            XCTAssertEqual(probe.checkedSlots, [[.solana]])
            let expectedSolana = try solanaFunds == .empty
                ? passwordKeys(vector)[.solana]
                : noPasswordKeys(vector.mnemonic)[.solana]
            XCTAssertEqual(try slotKeys(in: persisted)[.solana], expectedSolana)
            XCTAssertEqual(
                watched.watchedSlots(in: earlier.metaId), [.solana],
                "Whichever Solana account the wallet did not get stays watched (\(solanaFunds))"
            )

            // Every stored account resolves to the secret that re-derives its key: the
            // signing material for Bitcoin, Solana and Taira, and TON's credentials.
            for chain in signingChains {
                let secret = try XCTUnwrap(provider.secret(for: persisted, chain: chain))
                let slot = try XCTUnwrap(UniversalWalletSlot(chainId: chain.chainId))
                XCTAssertEqual(try slot.publicKey(for: secret), slot.storedAccount(in: persisted)?.publicKey)
            }
            // A real signature by the resolved key verifies against the stored Solana and
            // Taira accounts, whichever of the two each one is.
            let challenge = Data("Fearless universal wallet password".utf8)
            let solanaSecret = try XCTUnwrap(
                provider.secret(for: persisted, chain: UniversalWalletRegistry.solanaMainnetChainModel)
            )
            let solanaSignature = try SolanaSigner.signMessage(
                mnemonic: solanaSecret.mnemonic, message: challenge, passphrase: solanaSecret.passphrase
            )
            let solanaKey = try XCTUnwrap(UniversalWalletSlot.solana.storedAccount(in: persisted)).publicKey
            XCTAssertTrue(try Curve25519.Signing.PublicKey(rawRepresentation: solanaKey)
                .isValidSignature(solanaSignature.signature, for: challenge))
            let tairaSecret = try XCTUnwrap(provider.secret(for: persisted, chain: UniversalWalletRegistry.tairaChainModel))
            let taira = try IrohaKeyDerivation.deriveAccount(
                mnemonic: tairaSecret.mnemonic, passphrase: tairaSecret.passphrase
            )
            let tairaSignature = try Curve25519.Signing.PrivateKey(rawRepresentation: taira.privateKey)
                .signature(for: challenge)
            let tairaKey = try XCTUnwrap(UniversalWalletSlot.taira.storedAccount(in: persisted)).publicKey
            XCTAssertTrue(try Curve25519.Signing.PublicKey(rawRepresentation: tairaKey)
                .isValidSignature(tairaSignature, for: challenge))
            XCTAssertEqual(tairaSecret.passphrase, "")
            XCTAssertEqual(solanaSecret.passphrase, solanaFunds == .empty ? Self.password : "")

            let tonAccount = try XCTUnwrap(UniversalWalletSlot.ton.storedAccount(in: persisted))
            let tonKey = try UniversalWalletSlot.ton.publicKey(for: UniversalWalletSecret(mnemonic: vector.mnemonic, passphrase: ""))
            XCTAssertEqual(tonAccount.publicKey, tonKey)

            let backup = OpenBackupAccount(
                address: persisted.backupAddress,
                passphrase: vector.mnemonic,
                substrateDerivationPath: Self.substratePath,
                ethDerivationPath: DerivationPathConstants.defaultEthereum,
                backupAccountType: [.passphrase]
            )
            XCTAssertEqual(GoogleDriveBackupContent.appOwnedAccountsNotRestored(from: persisted, by: backup), [])

            // Enrolment at the next start changes nothing and checks nothing.
            let again = StaticFundsProbe(funds: [:])
            let restarted = try await UniversalWalletAccountProvisioning.enrollingMissingAccounts(
                in: persisted, root: root, probe: again, watchedAccounts: watched
            )
            XCTAssertEqual(restarted, persisted)
            XCTAssertTrue(again.checkedSlots.isEmpty)
        }
    }

    // MARK: - Switch

    func testSwitchReplacesOnlyEmptyNoPasswordAccounts() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(vector.mnemonic, enrollment: .unchecked, keystore: keystore)
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        let probe = StaticFundsProbe(funds: [
            .bitcoinMainnet: .funded, .bitcoinTestnet: .empty, .solana: .unknown, .ton: .empty, .taira: .empty
        ])
        let switcher = UniversalWalletPasswordSwitcher(
            mnemonicProvider: provider, fundsProbe: { probe }, watchedAccounts: watched
        )

        let accounts = switcher.noPasswordAccounts(in: wallet)
        XCTAssertEqual(accounts.map(\.slot), UniversalWalletSlot.allCases)
        let bitcoin = try XCTUnwrap(accounts.first { $0.slot == .bitcoinMainnet })
        XCTAssertEqual(bitcoin.newAddress, vector.expected.bitcoin["mainnet"]?.firstReceiveAddress)
        XCTAssertEqual(
            bitcoin.oldAddress,
            try BitcoinKeyDerivation.deriveAccount(mnemonic: vector.mnemonic).firstReceiveAddress
        )

        let result = await switcher.switching(accounts, in: wallet)
        XCTAssertEqual(result.outcomes, [
            .bitcoinMainnet: .stillFunded, .solana: .unchecked,
            .bitcoinTestnet: .switched, .ton: .switched, .taira: .switched
        ])
        let keys = try slotKeys(in: result.wallet)
        let wordsOnly = try noPasswordKeys(vector.mnemonic)
        let protected = try passwordKeys(vector)
        XCTAssertEqual(keys[.bitcoinMainnet], wordsOnly[.bitcoinMainnet])
        XCTAssertEqual(keys[.solana], wordsOnly[.solana])
        XCTAssertEqual(keys[.bitcoinTestnet], protected[.bitcoinTestnet])
        XCTAssertEqual(keys[.ton], protected[.ton])
        XCTAssertEqual(keys[.taira], protected[.taira])
        XCTAssertEqual(result.wallet.chainAccounts.count, wallet.chainAccounts.count)

        XCTAssertEqual(
            try provider.secret(for: result.wallet, chain: UniversalWalletRegistry.tairaChainModel)?.passphrase,
            Self.password
        )
        XCTAssertEqual(
            try provider.secret(for: result.wallet, chain: UniversalWalletRegistry.bitcoinMainnetChainModel)?.passphrase,
            ""
        )
        XCTAssertEqual(switcher.noPasswordAccounts(in: result.wallet).map(\.slot), [.bitcoinMainnet, .solana])
    }

    /// After a switch the wallet's Bitcoin account is another one: no cached scan of the old
    /// account may answer for it, while other wallets keep theirs.
    func testSwitchDropsOnlyThatWalletsBitcoinScans() async throws {
        let cache = BitcoinWalletBalanceCache()
        let key = { (walletId: String) in
            BitcoinWalletBalanceCache.Key(
                walletId: walletId, network: .mainnet, baseURL: nil, gapLimit: 20,
                maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead
            )
        }
        var loads: [String] = []
        let load = { (walletId: String, sats: Int64) in
            { () async throws -> BitcoinBalanceSyncResult in
                loads.append(walletId)
                return BitcoinBalanceSyncResult(
                    confirmedSats: sats, mempoolSats: 0, totalSats: sats, usedAddresses: [],
                    discovery: BitcoinReceiveDiscoveryResult(
                        addresses: [], gapLimit: 20, lastUsedIndex: nil, nextReceiveAddress: "",
                        nextReceiveIndex: 0, usedAddresses: []
                    )
                )
            }
        }

        _ = try await cache.value(for: key("switched"), loader: load("switched", 5))
        _ = try await cache.value(for: key("other"), loader: load("other", 7))
        await cache.invalidate(walletId: "switched")
        let rescanned = try await cache.value(for: key("switched"), loader: load("switched", 0))
        let kept = try await cache.value(for: key("other"), loader: load("other", 0))

        XCTAssertEqual(rescanned.totalSats, 0)
        XCTAssertEqual(kept.totalSats, 7)
        XCTAssertEqual(loads, ["switched", "other", "switched"])
    }

    func testNothingToSwitchWithoutAPassword() throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(vector.mnemonic, substratePath: "", enrollment: .unchecked, keystore: keystore)
        let switcher = UniversalWalletPasswordSwitcher(
            mnemonicProvider: KeychainUniversalWalletMnemonicProvider(keystore: keystore),
            fundsProbe: { StaticFundsProbe(funds: [:]) },
            watchedAccounts: watched
        )
        XCTAssertEqual(switcher.noPasswordAccounts(in: wallet), [])
    }

    func testNoticeIsShownOncePerWallet() throws {
        let suite = "UniversalWalletPasswordTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let tracker = UniversalWalletPasswordNoticeTracker(userDefaults: defaults)

        XCTAssertFalse(tracker.wasShown(for: "a"))
        tracker.markShown(for: "a")
        tracker.markShown(for: "a")
        XCTAssertTrue(tracker.wasShown(for: "a"))
        XCTAssertFalse(tracker.wasShown(for: "b"))
        XCTAssertEqual(defaults.stringArray(forKey: UniversalWalletPasswordNoticeTracker.key), ["a"])
    }

    func testNoticeListsEveryOldAndNewAddress() throws {
        let account = UniversalWalletNoPasswordAccount(
            slot: .solana, oldAddress: "old-solana", newAddress: "new-solana", newPublicKey: Data(repeating: 1, count: 32)
        )
        let viewModel = UniversalWalletPasswordNotice.notice(
            for: [account], locale: Locale(identifier: "en"), onSwitch: {}, onCopy: { _ in }, onDismiss: {}
        )
        XCTAssertTrue(viewModel.message?.contains("old-solana") == true)
        XCTAssertTrue(viewModel.message?.contains("new-solana") == true)
        XCTAssertEqual(viewModel.actions.count, 2)

        let outcomes = UniversalWalletPasswordNotice.outcomes(
            [.solana: .stillFunded], for: [account], locale: Locale(identifier: "en")
        )
        XCTAssertTrue(outcomes.message?.contains(UniversalWalletRegistry.solanaMainnet.name) == true)
    }

    // MARK: - Helpers

    private var signingChains: [ChainModel] {
        [
            UniversalWalletRegistry.bitcoinMainnetChainModel,
            UniversalWalletRegistry.solanaMainnetChainModel,
            UniversalWalletRegistry.tairaChainModel
        ]
    }

    private func trezorVector() throws -> PassphraseFixture.Vector {
        let vector = try XCTUnwrap(try loadFixture().vectors.first { $0.id == "import12-trezor" })
        XCTAssertEqual(vector.passphrase, Self.password)
        return vector
    }

    private func importWallet(
        _ mnemonic: String,
        substratePath: String = UniversalWalletPasswordTests.substratePath,
        ethereumPath: String = DerivationPathConstants.defaultEthereum,
        enrollment: UniversalWalletPasswordEnrollment,
        keystore: InMemoryKeychain
    ) throws -> MetaAccountModel {
        var request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: mnemonic),
            username: "password wallet",
            substrateDerivationPath: substratePath,
            ethereumDerivationPath: ethereumPath,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        request.universalWalletEnrollment = enrollment
        let operation = MetaAccountOperationFactory(keystore: keystore, watchedAccounts: watched).newMetaAccountOperation(
            request: request,
            isBackuped: true
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        (operation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        return try JSONDecoder().decode(MetaAccountModel.self, from: JSONEncoder().encode(wallet))
    }

    private func seedEarlierReleaseWallet(_ mnemonic: String, keystore: InMemoryKeychain) throws -> MetaAccountModel {
        let metaId = UUID().uuidString
        let entropy = try IRMnemonicCreator().mnemonic(fromList: mnemonic).entropy()
        try keystore.saveKey(entropy, with: fearless.KeystoreTagV2.entropyTagForMetaId(metaId))
        try keystore.saveKey(Data(Self.substratePath.utf8), with: fearless.KeystoreTagV2.substrateDerivationTagForMetaId(metaId))
        try keystore.saveKey(
            Data(DerivationPathConstants.defaultEthereum.utf8),
            with: fearless.KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)
        )

        // The released derivations: no passphrase, no Solana account.
        let bitcoin = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: .mainnet).publicKey
        let bitcoinTestnet = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: .testnet).publicKey
        let ton = try TonKeyDerivation.deriveAccount(mnemonic: mnemonic).publicKey
        let taira = try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic).publicKey
        let accounts: Set<ChainAccountModel> = [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.bitcoinMainnet.chainId, accountId: bitcoin, publicKey: bitcoin,
                cryptoType: CryptoType.ecdsa.rawValue, ethereumBased: false
            ),
            ChainAccountModel(
                chainId: UniversalWalletRegistry.bitcoinTestnet.chainId, accountId: bitcoinTestnet,
                publicKey: bitcoinTestnet, cryptoType: CryptoType.ecdsa.rawValue, ethereumBased: false
            ),
            ChainAccountModel(
                chainId: UniversalWalletRegistry.tonMainnetRegistryEntry.chainId, accountId: ton, publicKey: ton,
                cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
            ),
            ChainAccountModel(
                chainId: UniversalWalletRegistry.taira.chainId, accountId: taira, publicKey: taira,
                cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false
            )
        ]
        let substrateKey = Data(repeating: 7, count: 32)
        let wallet = MetaAccountModel(
            metaId: metaId,
            name: "4.1 password wallet",
            substrateAccountId: substrateKey,
            substrateCryptoType: CryptoType.sr25519.rawValue,
            substratePublicKey: substrateKey,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: accounts,
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
        return try JSONDecoder().decode(MetaAccountModel.self, from: JSONEncoder().encode(wallet))
    }

    private func slotKeys(in wallet: MetaAccountModel) throws -> [UniversalWalletSlot: Data] {
        var keys: [UniversalWalletSlot: Data] = [:]
        for slot in UniversalWalletSlot.allCases {
            keys[slot] = try XCTUnwrap(slot.storedAccount(in: wallet), "\(slot)").publicKey
        }
        return keys
    }

    private func passwordKeys(_ vector: PassphraseFixture.Vector) throws -> [UniversalWalletSlot: Data] {
        try keys(for: UniversalWalletSecret(mnemonic: vector.mnemonic, passphrase: vector.passphrase))
    }

    private func noPasswordKeys(_ mnemonic: String) throws -> [UniversalWalletSlot: Data] {
        try keys(for: UniversalWalletSecret(mnemonic: mnemonic, passphrase: ""))
    }

    private func keys(for secret: UniversalWalletSecret) throws -> [UniversalWalletSlot: Data] {
        var keys: [UniversalWalletSlot: Data] = [:]
        for slot in UniversalWalletSlot.allCases {
            keys[slot] = try slot.publicKey(for: secret)
        }
        return keys
    }

    private func importRequest(_ mnemonic: String, substratePath: String) throws -> MetaAccountImportRequest {
        MetaAccountImportRequest(
            source: .mnemonic(data: MetaAccountImportRequestSource.MnemonicImportRequestData(
                mnemonic: try IRMnemonicCreator().mnemonic(fromList: mnemonic),
                substrateDerivationPath: substratePath,
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum
            )),
            username: "imported",
            cryptoType: .sr25519,
            defaultChainId: nil
        )
    }

    private func makeImportInteractor(factory: RecordingOperationFactory) -> BaseAccountImportInteractor {
        BaseAccountImportInteractor(
            accountOperationFactory: factory,
            accountRepository: AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade())
                .createMetaAccountRepository(for: nil, sortDescriptors: []),
            operationManager: OperationManager(),
            keystoreImportService: KeystoreImportService(logger: Logger.shared),
            defaultSource: .mnemonic
        )
    }

    private func loadFixture() throws -> PassphraseFixture {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent("docs/universal-wallet-v2-passphrase-vectors.json")
        return try JSONDecoder().decode(PassphraseFixture.self, from: Data(contentsOf: url))
    }

    private func pbkdf2Seed(mnemonic: String, salt: String) throws -> Data {
        let password = Array(mnemonic.utf8)
        let saltBytes = Array(salt.utf8)
        var output = [UInt8](repeating: 0, count: 64)
        let status = password.withUnsafeBufferPointer { passwordBuffer in
            passwordBuffer.baseAddress!.withMemoryRebound(to: Int8.self, capacity: password.count) { passwordPointer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2), passwordPointer, password.count, saltBytes, saltBytes.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512), 2048, &output, output.count
                )
            }
        }
        XCTAssertEqual(status, Int32(kCCSuccess))
        return Data(output)
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Watched old addresses (spec rule 9)

extension UniversalWalletPasswordTests {
    /// The switch found the old Solana address empty; a deposit landed there before the switched
    /// wallet was saved. The next check moves Solana back to the old address.
    func testDepositBeforeTheSwitchCommitsBringsTheOldAddressBack() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(vector.mnemonic, enrollment: .unchecked, keystore: keystore)
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        let probe = StaticFundsProbe(funds: [.solana: .empty], protectedFunds: [.solana: .empty])
        let switcher = UniversalWalletPasswordSwitcher(
            mnemonicProvider: provider, fundsProbe: { probe }, watchedAccounts: watched
        )
        let solana = try XCTUnwrap(switcher.noPasswordAccounts(in: wallet).first { $0.slot == .solana })

        let switched = await switcher.switching([solana], in: wallet)
        XCTAssertEqual(switched.outcomes, [.solana: .switched])
        XCTAssertEqual(
            watched.watchedSlots(in: wallet.metaId), Set(UniversalWalletSlot.allCases),
            "An import that kept every old account watches every protected one"
        )

        probe.deposit(at: .solana)
        let result = await checker(provider, probe).check(switched.wallet)

        XCTAssertEqual(result.movedBack, [.solana])
        XCTAssertEqual(result.arrivals, [])
        XCTAssertEqual(try slotKeys(in: result.wallet)[.solana], try noPasswordKeys(vector.mnemonic)[.solana])
        XCTAssertEqual(
            try provider.secret(for: result.wallet, chain: UniversalWalletRegistry.solanaMainnetChainModel)?.passphrase,
            ""
        )
        XCTAssertTrue(switcher.noPasswordAccounts(in: result.wallet).contains { $0.slot == .solana })
        XCTAssertTrue(watched.watchedSlots(in: wallet.metaId).contains(.solana), "It stays watched")
    }

    /// An import found some old addresses empty and took the password-protected ones there, and
    /// kept the old ones elsewhere. Each network watches the account it did not get; one of the
    /// old addresses is paid later.
    func testOldAddressAnImportFoundEmptyIsWatchedAndComesBackWhenPaid() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(
            vector.mnemonic,
            enrollment: .probed([
                .bitcoinMainnet: .empty, .bitcoinTestnet: .funded, .solana: .unknown, .ton: .empty, .taira: .empty
            ]),
            keystore: keystore
        )
        XCTAssertEqual(watched.watchedSlots(in: wallet.metaId), Set(UniversalWalletSlot.allCases))
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        let quiet = StaticFundsProbe(funds: [.bitcoinMainnet: .empty, .ton: .empty, .taira: .empty])
        let unchanged = await checker(provider, quiet).check(wallet)
        XCTAssertEqual(unchanged.wallet, wallet)
        XCTAssertEqual(quiet.checkedSlots, [[.bitcoinMainnet, .ton, .taira]], "Old accounts beside protected ones")
        XCTAssertEqual(
            quiet.checkedProtectedSlots, [[.bitcoinTestnet, .solana]],
            "Protected accounts beside kept old ones; nothing arrived, so nothing more is read"
        )

        let paid = StaticFundsProbe(
            funds: [.bitcoinMainnet: .funded, .ton: .empty, .taira: .empty],
            protectedFunds: [.bitcoinMainnet: .empty]
        )
        let result = await checker(provider, paid).check(wallet)
        XCTAssertEqual(result.movedBack, [.bitcoinMainnet])
        XCTAssertEqual(result.movedToProtected, [])
        XCTAssertEqual(paid.checkedProtectedSlots, [[.bitcoinTestnet, .solana], [.bitcoinMainnet]])
        let keys = try slotKeys(in: result.wallet)
        XCTAssertEqual(keys[.bitcoinMainnet], try noPasswordKeys(vector.mnemonic)[.bitcoinMainnet])
        XCTAssertEqual(keys[.ton], try passwordKeys(vector)[.ton])
    }

    /// Funds at a watched old address while the password-protected account holds funds, or
    /// cannot be checked: that account stays and the arrival is reported once per balance.
    func testDepositAtTheOldAddressNeverHidesTheProtectedAccount() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        let wallet = try importWallet(vector.mnemonic, enrollment: .generated, keystore: keystore)
        watched.watch([.solana, .taira], in: wallet.metaId)
        let oldSolana = try SolanaKeyDerivation.deriveAccount(mnemonic: vector.mnemonic).address

        let probe = StaticFundsProbe(
            funds: [.solana: .funded, .taira: .funded],
            protectedFunds: [.solana: .funded],
            balance: "1.5 SOL"
        )
        let result = await checker(provider, probe).check(wallet)

        XCTAssertEqual(result.wallet, wallet, "Funds at the password-protected accounts stay visible")
        XCTAssertEqual(result.movedBack, [])
        XCTAssertEqual(result.arrivals.map(\.slot), [.solana, .taira], "Taira's protected account was not checkable")
        XCTAssertEqual(result.arrivals.first?.oldAddress, oldSolana)
        XCTAssertEqual(result.arrivals.first?.balance, "1.5 SOL")

        XCTAssertEqual(watched.unnotified(result.arrivals, in: wallet.metaId), result.arrivals)
        watched.markNotified(result.arrivals, in: wallet.metaId)
        XCTAssertEqual(watched.unnotified(result.arrivals, in: wallet.metaId), [])
        let more = UniversalWalletOldAddressArrival(slot: .solana, oldAddress: oldSolana, balance: "2 SOL")
        XCTAssertEqual(watched.unnotified([more], in: wallet.metaId), [more], "New funds are reported again")

        let viewModel = UniversalWalletPasswordNotice.arrivals(result.arrivals, locale: Locale(identifier: "en")) {}
        XCTAssertTrue(viewModel.message?.contains(oldSolana) == true)
        XCTAssertTrue(viewModel.message?.contains("1.5 SOL") == true)
    }

    /// The watch list is stored: after a relaunch (a new store on the same defaults) the old
    /// address is still checked. Only removing the wallet forgets it.
    func testWatchedOldAddressesSurviveARelaunch() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(vector.mnemonic, enrollment: .unchecked, keystore: keystore)
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        let probe = StaticFundsProbe(funds: [.taira: .empty], protectedFunds: [.taira: .empty])
        let switcher = UniversalWalletPasswordSwitcher(
            mnemonicProvider: provider, fundsProbe: { probe }, watchedAccounts: watched
        )
        let taira = try XCTUnwrap(switcher.noPasswordAccounts(in: wallet).first { $0.slot == .taira })
        let switched = await switcher.switching([taira], in: wallet).wallet
        let persisted = try JSONDecoder().decode(MetaAccountModel.self, from: JSONEncoder().encode(switched))

        let relaunched = UniversalWalletWatchedAccountsStore(userDefaults: try XCTUnwrap(UserDefaults(suiteName: defaultsSuite)))
        XCTAssertEqual(relaunched.watchedSlots(in: wallet.metaId), Set(UniversalWalletSlot.allCases))
        probe.deposit(at: .taira)
        let result = await UniversalWalletWatchedAccountsChecker(
            mnemonicProvider: provider, watchedAccounts: relaunched, fundsProbe: { probe }
        ).check(persisted)
        XCTAssertEqual(result.movedBack, [.taira])

        relaunched.forget(walletId: wallet.metaId)
        XCTAssertEqual(watched.watchedSlots(in: wallet.metaId), [])
    }

    func testNothingWatchedMeansNoCheck() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(vector.mnemonic, enrollment: .generated, keystore: keystore)
        let probe = StaticFundsProbe(funds: [.solana: .funded])
        let result = await checker(KeychainUniversalWalletMnemonicProvider(keystore: keystore), probe).check(wallet)
        XCTAssertEqual(result.wallet, wallet)
        XCTAssertTrue(probe.checkedSlots.isEmpty)
        XCTAssertTrue(probe.checkedProtectedSlots.isEmpty)
    }

    /// A password wallet created on this build has funds at its protected Solana and Taira
    /// accounts. Its words and password are restored while no balance can be read, so the import
    /// keeps every old account. Once a check reads Solana's old account empty, Solana shows the
    /// protected one; Taira's old account holds funds too, so that arrival is reported.
    func testProtectedAccountsARestoreCouldNotCheckAreShownOnceReadable() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let restored = try importWallet(vector.mnemonic, enrollment: .probed([:]), keystore: keystore)
        XCTAssertEqual(try slotKeys(in: restored), try noPasswordKeys(vector.mnemonic), "Nothing could be checked")
        XCTAssertEqual(watched.watchedSlots(in: restored.metaId), Set(UniversalWalletSlot.allCases))
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        let offline = StaticFundsProbe(funds: [:])
        let stillOffline = await checker(provider, offline).check(restored)
        XCTAssertEqual(stillOffline.wallet, restored, "Unknown balances move nothing")
        XCTAssertEqual(offline.checkedProtectedSlots, [Set(UniversalWalletSlot.allCases)])

        let online = StaticFundsProbe(
            funds: [.solana: .empty, .taira: .funded],
            protectedFunds: [.solana: .funded, .taira: .funded],
            balance: "3 XOR"
        )
        let result = await checker(provider, online).check(restored)
        XCTAssertEqual(result.movedToProtected, [.solana])
        XCTAssertEqual(result.movedBack, [])
        let keys = try slotKeys(in: result.wallet)
        XCTAssertEqual(keys[.solana], try passwordKeys(vector)[.solana])
        XCTAssertEqual(keys[.taira], try noPasswordKeys(vector.mnemonic)[.taira])
        XCTAssertEqual(keys[.bitcoinMainnet], try noPasswordKeys(vector.mnemonic)[.bitcoinMainnet])
        let protectedTaira = try XCTUnwrap(passwordKeys(vector)[.taira])
        XCTAssertEqual(result.arrivals, [UniversalWalletOldAddressArrival(
            slot: .taira,
            oldAddress: try XCTUnwrap(UniversalWalletChainAccountSupport.address(
                for: UniversalWalletSlot.taira.chainId, publicKey: protectedTaira
            )),
            balance: "3 XOR",
            atProtectedAddress: true,
            walletId: restored.metaId
        )])
        XCTAssertEqual(
            try provider.secret(for: result.wallet, chain: UniversalWalletRegistry.solanaMainnetChainModel)?.passphrase,
            Self.password,
            "Solana signs with the password again"
        )
    }

    /// An earlier release's wallet switched Taira to its protected account and showed it. Funds
    /// then reached the old address while the protected one was empty, so Taira went back. A payer
    /// still sends to the protected address: the arrival is reported while the old address holds
    /// funds, and Taira shows the protected account again once the old one is empty.
    func testProtectedAddressStaysWatchedAfterTheNetworkMovesBack() async throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let earlier = try seedEarlierReleaseWallet(vector.mnemonic, keystore: keystore)
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)
        let probe = StaticFundsProbe(funds: [.taira: .empty], protectedFunds: [.taira: .empty], balance: "5 XOR")
        let switcher = UniversalWalletPasswordSwitcher(
            mnemonicProvider: provider, fundsProbe: { probe }, watchedAccounts: watched
        )
        let taira = try XCTUnwrap(switcher.noPasswordAccounts(in: earlier).first { $0.slot == .taira })
        let switched = await switcher.switching([taira], in: earlier)
        XCTAssertEqual(switched.outcomes, [.taira: .switched])
        XCTAssertEqual(watched.watchedSlots(in: earlier.metaId), [.taira])

        probe.deposit(at: .taira)
        let back = await checker(provider, probe).check(switched.wallet)
        XCTAssertEqual(back.movedBack, [.taira])
        // That release created no Solana account, so the Taira slot is read on its own.
        XCTAssertEqual(
            UniversalWalletSlot.taira.storedAccount(in: back.wallet)?.publicKey,
            try noPasswordKeys(vector.mnemonic)[.taira]
        )

        probe.deposit(at: .taira, protected: true)
        let reported = await checker(provider, probe).check(back.wallet)
        XCTAssertEqual(reported.wallet, back.wallet, "The old account holds funds too, so it stays")
        XCTAssertEqual(reported.arrivals, [UniversalWalletOldAddressArrival(
            slot: .taira,
            oldAddress: taira.newAddress,
            balance: "5 XOR",
            atProtectedAddress: true,
            walletId: earlier.metaId
        )])

        let emptied = StaticFundsProbe(funds: [.taira: .empty], protectedFunds: [.taira: .funded])
        let forward = await checker(provider, emptied).check(back.wallet)
        XCTAssertEqual(forward.movedToProtected, [.taira])
        XCTAssertEqual(forward.movedBack, [])
        XCTAssertEqual(UniversalWalletSlot.taira.storedAccount(in: forward.wallet)?.publicKey, taira.newPublicKey)
        XCTAssertEqual(
            try provider.secret(for: forward.wallet, chain: UniversalWalletRegistry.tairaChainModel)?.passphrase,
            Self.password
        )
        XCTAssertEqual(watched.watchedSlots(in: earlier.metaId), [.taira], "Taira stays watched either way")
    }

    /// Funds at a protected address get their own explanation and a title that fits both kinds,
    /// and they are reported apart from the same balance at the old address.
    func testArrivalAtAProtectedAddressExplainsThatTheWalletSwitchesToIt() {
        let languages = Locale(identifier: "en").rLanguages
        let atProtected = UniversalWalletOldAddressArrival(
            slot: .solana, oldAddress: "protected-solana", balance: "2 SOL", atProtectedAddress: true
        )
        let atOld = UniversalWalletOldAddressArrival(slot: .taira, oldAddress: "old-taira", balance: nil)
        let oldMessage = R.string.localizable.universalPasswordArrivalMessage(preferredLanguages: languages)
        let protectedMessage = R.string.localizable
            .universalPasswordArrivalProtectedMessage(preferredLanguages: languages)

        let onlyProtected = UniversalWalletPasswordNotice.arrivals([atProtected], locale: Locale(identifier: "en")) {}
        XCTAssertEqual(
            onlyProtected.title,
            R.string.localizable.universalPasswordArrivalProtectedTitle(preferredLanguages: languages)
        )
        XCTAssertTrue(onlyProtected.message?.hasPrefix(protectedMessage) == true)
        XCTAssertTrue(onlyProtected.message?.contains("protected-solana (2 SOL)") == true)
        XCTAssertFalse(onlyProtected.message?.contains(oldMessage) == true)

        let onlyOld = UniversalWalletPasswordNotice.arrivals([atOld], locale: Locale(identifier: "en")) {}
        XCTAssertEqual(onlyOld.title, R.string.localizable.universalPasswordArrivalTitle(preferredLanguages: languages))
        XCTAssertFalse(onlyOld.message?.contains(protectedMessage) == true)

        let both = UniversalWalletPasswordNotice.arrivals([atOld, atProtected], locale: Locale(identifier: "en")) {}
        XCTAssertEqual(both.title, onlyProtected.title)
        XCTAssertTrue(both.message?.contains(oldMessage) == true)
        XCTAssertTrue(both.message?.contains(protectedMessage) == true)
        XCTAssertTrue(both.message?.contains("old-taira") == true)

        let sameBalanceAtOld = UniversalWalletOldAddressArrival(
            slot: .solana, oldAddress: "old-solana", balance: "2 SOL"
        )
        XCTAssertNotEqual(atProtected.notificationKey, sameBalanceAtOld.notificationKey)
        let sameBalanceElsewhere = UniversalWalletOldAddressArrival(
            slot: .taira, oldAddress: "other-taira", balance: nil
        )
        XCTAssertNotEqual(atOld.notificationKey, sameBalanceElsewhere.notificationKey, "The address is part of the key")
    }

    private func checker(
        _ provider: KeychainUniversalWalletMnemonicProvider,
        _ probe: StaticFundsProbe
    ) -> UniversalWalletWatchedAccountsChecker {
        UniversalWalletWatchedAccountsChecker(mnemonicProvider: provider, watchedAccounts: watched, fundsProbe: { probe })
    }
}

// MARK: - Exports, backups and reimport

extension UniversalWalletPasswordTests {
    /// The whole-wallet export never offers the words alone for an account the password
    /// protects: the Substrate row carries the `///password`, and so does every protected
    /// universal row. Accounts the words alone open show their plain path.
    func testWholeWalletExportShowsThePasswordEveryProtectedAccountNeeds() throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(
            vector.mnemonic,
            enrollment: .probed([
                .bitcoinMainnet: .funded, .bitcoinTestnet: .empty, .solana: .empty, .ton: .empty, .taira: .empty
            ]),
            keystore: keystore
        )
        let reader = VerifiedMnemonicExportReader(keystore: keystore)

        XCTAssertEqual(try exportedPath(reader, wallet, ChainAccountRecordsFixture.chain(id: "export-substrate")), Self.substratePath)
        XCTAssertEqual(
            try exportedPath(reader, wallet, UniversalWalletRegistry.solanaMainnetChainModel),
            "\(UniversalWalletDerivationPaths.solanaDefault)///\(Self.password)"
        )
        XCTAssertEqual(
            try exportedPath(reader, wallet, UniversalWalletRegistry.tairaChainModel),
            "\(UniversalWalletDerivationPaths.irohaDefault)///\(Self.password)"
        )
        XCTAssertEqual(
            try exportedPath(reader, wallet, UniversalWalletRegistry.bitcoinMainnetChainModel),
            UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
            "The old Bitcoin account opens with the words alone"
        )
    }

    /// The password only in the Ethereum path: the Ethereum row shows it, and the protected
    /// universal rows carry it too.
    func testEthereumOnlyPasswordIsShownWhereverItIsNeeded() throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let ethereumPath = "\(DerivationPathConstants.defaultEthereum)///\(Self.password)"
        let wallet = try importWallet(
            vector.mnemonic, substratePath: "//polkadot", ethereumPath: ethereumPath,
            enrollment: .generated, keystore: keystore
        )
        XCTAssertEqual(try slotKeys(in: wallet), try passwordKeys(vector))
        let reader = VerifiedMnemonicExportReader(keystore: keystore)

        XCTAssertEqual(try exportedPath(reader, wallet, ChainAccountRecordsFixture.chain(id: "export-substrate")), "//polkadot")
        XCTAssertEqual(
            try exportedPath(reader, wallet, ChainAccountRecordsFixture.chain(id: "export-evm", ethereumBased: true)),
            ethereumPath
        )
        XCTAssertEqual(
            try exportedPath(reader, wallet, UniversalWalletRegistry.solanaMainnetChainModel),
            "\(UniversalWalletDerivationPaths.solanaDefault)///\(Self.password)"
        )
    }

    /// A Google Drive backup stores both paths as typed, so restoring it re-derives the
    /// password-protected accounts, and the backup screen reports nothing missing.
    func testGoogleDriveBackupRoundTripRestoresTheProtectedAccounts() throws {
        let vector = try trezorVector()
        let keystore = InMemoryKeychain()
        let wallet = try importWallet(vector.mnemonic, enrollment: .generated, keystore: keystore)
        let backup = OpenBackupAccount(
            address: wallet.backupAddress,
            passphrase: vector.mnemonic,
            substrateDerivationPath: try keystore.fetchDeriviationForAddress(
                fearless.KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId)
            ),
            ethDerivationPath: try keystore.fetchDeriviationForAddress(
                fearless.KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId)
            ),
            backupAccountType: [.passphrase]
        )
        XCTAssertEqual(backup.substrateDerivationPath, Self.substratePath)
        XCTAssertEqual(GoogleDriveBackupContent.appOwnedAccountsNotRestored(from: wallet, by: backup), [])

        let empty = Dictionary(uniqueKeysWithValues: UniversalWalletSlot.allCases.map { ($0, UniversalWalletFundsState.empty) })
        let restored = try importWallet(
            try XCTUnwrap(backup.passphrase),
            substratePath: try XCTUnwrap(backup.substrateDerivationPath),
            ethereumPath: try XCTUnwrap(backup.ethDerivationPath),
            enrollment: .probed(empty),
            keystore: InMemoryKeychain()
        )
        XCTAssertNotEqual(restored.metaId, wallet.metaId)
        XCTAssertEqual(try slotKeys(in: restored), try slotKeys(in: wallet))
        XCTAssertEqual(try slotKeys(in: restored), try passwordKeys(vector))
    }

    /// Nothing marks a wallet as created: words a deleted created wallet used are imported like
    /// any others, so the funds of the accounts they open alone are always checked.
    func testReimportAfterDeletingACreatedWalletChecksFundsAgain() throws {
        let vector = try trezorVector()
        let created = try importWallet(vector.mnemonic, enrollment: .generated, keystore: InMemoryKeychain())
        watched.forget(walletId: created.metaId)

        let factory = RecordingOperationFactory()
        let probe = StaticFundsProbe(funds: [
            .bitcoinMainnet: .empty, .bitcoinTestnet: .empty, .solana: .funded, .ton: .empty, .taira: .empty
        ])
        let interactor = makeImportInteractor(factory: factory)
        interactor.universalWalletFundsProbe = probe
        let requested = expectation(description: "Reimport request built after the funds check")
        factory.onMnemonicRequest = { _ in requested.fulfill() }

        interactor.importMetaAccount(request: try importRequest(vector.mnemonic, substratePath: Self.substratePath))
        wait(for: [requested], timeout: 10)

        XCTAssertEqual(probe.checkedMnemonics, [vector.mnemonic])
        XCTAssertEqual(
            factory.mnemonicRequests.first?.universalWalletEnrollment,
            .imported(keepingNoPassword: [.solana]),
            "Only Solana's old address held funds"
        )
    }

    private func exportedPath(
        _ reader: VerifiedMnemonicExportReader,
        _ wallet: MetaAccountModel,
        _ chain: ChainModel
    ) throws -> String? {
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        return try reader.fetch(wallet: wallet, info: ChainAccountInfo(chain: chain, account: account)).derivationPath
    }
}

private struct PassphraseFixture: Decodable {
    struct Vector: Decodable {
        let id: String
        let mnemonic: String
        let wordCount: Int
        let passphrase: String
        let passphraseNfkdUtf8Hex: String
        let expected: Expected
    }

    struct Expected: Decodable {
        let bitcoin: [String: Bitcoin]
        let solana: Solana
        let ton: Ton
        let iroha: Iroha
    }

    struct Bitcoin: Decodable {
        let accountPath: String
        let firstReceivePath: String
        let accountXpub: String
        let firstReceiveAddress: String
    }

    struct Solana: Decodable {
        let derivationPath: String
        let publicKeyHex: String
        let address: String
    }

    struct Ton: Decodable {
        let derivationPath: String
        let publicKeyHex: String
        let addressBounceable: String
        let addressNonBounceable: String
        let testnetNonBounceable: String
    }

    struct Iroha: Decodable {
        let derivationPath: String
        let taira: IrohaNetwork
        let nexus: IrohaNetwork
    }

    struct IrohaNetwork: Decodable {
        let publicKeyHex: String
        let canonicalHex: String
        let i105: String
        let chainDiscriminant: Int
    }

    struct Source: Decodable {
        let id: String
        let substrateDerivationPath: String
        let ethereumPathPassword: String?
        let passphrase: String
    }

    struct NegativeCase: Decodable {
        let id: String
        let reason: String
    }

    let version: Int
    let vectors: [Vector]
    let passphraseSources: [Source]
    let negativeCases: [NegativeCase]
}

/// Answers checks of the accounts the words alone open from `funds`, and of the
/// password-protected ones from `protectedFunds`; it records the words-only checks.
private final class StaticFundsProbe: UniversalWalletFundsProbing {
    private let lock = NSLock()
    private var noPassword: [UniversalWalletSlot: UniversalWalletFundsState]
    private var protected: [UniversalWalletSlot: UniversalWalletFundsState]
    private let balance: String?
    private var mnemonics: [String] = []
    private var slots: [Set<UniversalWalletSlot>] = []
    private var protectedSlots: [Set<UniversalWalletSlot>] = []

    init(
        funds: [UniversalWalletSlot: UniversalWalletFundsState],
        protectedFunds: [UniversalWalletSlot: UniversalWalletFundsState] = [:],
        balance: String? = nil
    ) {
        noPassword = funds
        protected = protectedFunds
        self.balance = balance
    }

    var checkedMnemonics: [String] { lock.lock(); defer { lock.unlock() }; return mnemonics }
    var checkedSlots: [Set<UniversalWalletSlot>] { lock.lock(); defer { lock.unlock() }; return slots }
    var checkedProtectedSlots: [Set<UniversalWalletSlot>] {
        lock.lock(); defer { lock.unlock() }; return protectedSlots
    }

    /// A deposit lands at an address after an earlier check.
    func deposit(at slot: UniversalWalletSlot, protected isProtected: Bool = false) {
        lock.lock()
        if isProtected { protected[slot] = .funded } else { noPassword[slot] = .funded }
        lock.unlock()
    }

    func funds(
        of secret: UniversalWalletSecret,
        slots requested: Set<UniversalWalletSlot>
    ) async -> [UniversalWalletSlot: UniversalWalletFundsReading] {
        lock.lock()
        defer { lock.unlock() }
        let states: [UniversalWalletSlot: UniversalWalletFundsState]
        if secret.passphrase.isEmpty {
            mnemonics.append(secret.mnemonic)
            slots.append(requested)
            states = noPassword
        } else {
            protectedSlots.append(requested)
            states = protected
        }
        return states.filter { requested.contains($0.key) }.mapValues {
            UniversalWalletFundsReading(state: $0, balance: $0 == .funded ? balance : nil)
        }
    }
}

private final class RecordingOperationFactory: MetaAccountOperationFactoryProtocol {
    private(set) var mnemonicRequests: [MetaAccountImportMnemonicRequest] = []
    var onMnemonicRequest: ((MetaAccountImportMnemonicRequest) -> Void)?

    private func refused() -> BaseOperation<MetaAccountModel> {
        ClosureOperation<MetaAccountModel> { throw BaseOperationError.parentOperationCancelled }
    }

    func newMetaAccountOperation(request: MetaAccountImportMnemonicRequest, isBackuped _: Bool) -> BaseOperation<MetaAccountModel> {
        mnemonicRequests.append(request)
        onMnemonicRequest?(request)
        return refused()
    }

    func newMetaAccountOperation(request _: MetaAccountImportSeedRequest, isBackuped _: Bool) -> BaseOperation<MetaAccountModel> {
        refused()
    }

    func newMetaAccountOperation(request _: MetaAccountImportKeystoreRequest, isBackuped _: Bool) -> BaseOperation<MetaAccountModel> {
        refused()
    }

    func importChainAccountOperation(request _: ChainAccountImportMnemonicRequest) -> BaseOperation<MetaAccountModel> {
        refused()
    }

    func importChainAccountOperation(request _: ChainAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        refused()
    }

    func importChainAccountOperation(request _: ChainAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
        refused()
    }
}
