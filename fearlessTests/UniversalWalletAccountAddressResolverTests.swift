import TonAPI
import SSFModels
import SoraKeystore
import IrohaCrypto
import XCTest
import TonSwift
import CryptoKit
import RobinHood
import BigInt
@testable import fearless

final class UniversalWalletAccountAddressResolverTests: XCTestCase {
    func testResolvesBitcoinMainnetAddressFromMatchingChainAccountPublicKey() throws {
        let key = try BitcoinKeyDerivation.deriveKey(
            mnemonic: Self.mnemonic,
            derivationPath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
            network: .mainnet
        )
        let wallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            publicKey: key.publicKey
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId),
            wallet: wallet
        )

        XCTAssertEqual(address, key.address)
        XCTAssertTrue(address?.hasPrefix("bc1") == true)
    }

    func testResolvesBitcoinTestnetAddressFromMatchingChainAccountPublicKey() throws {
        let key = try BitcoinKeyDerivation.deriveKey(
            mnemonic: Self.mnemonic,
            derivationPath: UniversalWalletDerivationPaths.bitcoinTestnetFirstReceive,
            network: .testnet
        )
        let wallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinTestnet.chainId,
            publicKey: key.publicKey
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.bitcoinTestnet.chainId),
            wallet: wallet
        )

        XCTAssertEqual(address, key.address)
        XCTAssertTrue(address?.hasPrefix("tb1") == true)
    }

    func testBitcoinAddressResolutionFailsClosedWithoutMatchingChainAccount() {
        let wallet = AccountGenerator.generateMetaAccount()

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testBitcoinAddressResolutionRejectsMalformedPublicKey() {
        let wallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            publicKey: Data(repeating: 0x01, count: 32)
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testBitcoinProvisioningAddsCanonicalMainnetAccountAndIsIdempotent() throws {
        let wallet = AccountGenerator.generateMetaAccount()

        let provisioned = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: wallet,
            mnemonic: Self.mnemonic
        )
        let reprovisioned = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: provisioned,
            mnemonic: Self.mnemonic
        )

        let account = try XCTUnwrap(provisioned.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        XCTAssertEqual(account.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
        XCTAssertEqual(account.cryptoType, CryptoType.ecdsa.rawValue)
        XCTAssertEqual(account.accountId, account.publicKey)
        XCTAssertEqual(provisioned, reprovisioned)
        XCTAssertTrue(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.bitcoinMainnetChainModel,
                wallet: provisioned
            )?.hasPrefix("bc1") == true
        )
    }

    func testBitcoinProvisioningPreservesLegacyGenericAliasAndMismatchedAccounts() throws {
        let malformedAccount = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.id,
            accountId: Data(repeating: 0x01, count: 32),
            publicKey: Data(repeating: 0x01, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let mismatchedKey = try BitcoinKeyDerivation.deriveKey(
            mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            derivationPath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
            network: .mainnet
        ).publicKey
        let mismatchedAccount = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: mismatchedKey,
            publicKey: mismatchedKey,
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(
            with: [malformedAccount, mismatchedAccount]
        )

        XCTAssertThrowsError(try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: wallet,
            mnemonic: Self.mnemonic
        ))
        XCTAssertEqual(wallet.chainAccounts, [malformedAccount, mismatchedAccount])
    }

    func testTairaProvisioningAddsCanonicalI105AccountAndIsIdempotent() throws {
        let wallet = AccountGenerator.generateMetaAccount()

        let provisioned = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: wallet,
            mnemonic: Self.mnemonic
        )
        let reprovisioned = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: provisioned,
            mnemonic: Self.mnemonic
        )

        let account = try XCTUnwrap(provisioned.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )
        }))
        let address = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.tairaChainModel,
                wallet: provisioned
            )
        )
        let parsed = try IrohaAddressCodec.parse(
            address,
            expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        )

        XCTAssertEqual(account.chainId, UniversalWalletRegistry.taira.chainId)
        XCTAssertEqual(account.cryptoType, CryptoType.ed25519.rawValue)
        XCTAssertEqual(account.accountId, account.publicKey)
        XCTAssertEqual(account.publicKey.count, 32)
        XCTAssertEqual(parsed.publicKeyHex, account.publicKey.hexString())
        XCTAssertEqual(provisioned, reprovisioned)
    }

    func testTairaProvisioningPreservesGenericSr25519Account() throws {
        let malformed = ChainAccountModel(
            chainId: UniversalWalletRegistry.taira.id,
            accountId: Data(repeating: 0x42, count: 32),
            publicKey: Data(repeating: 0x42, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(with: [malformed])

        XCTAssertFalse(UniversalWalletChainAccountSupport.isValidTairaAccount(malformed))
        XCTAssertNil(wallet.fetch(for: UniversalWalletRegistry.tairaChainModel.accountRequest()))
        XCTAssertNil(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.tairaChainModel,
                wallet: wallet
            )
        )

        XCTAssertThrowsError(try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: wallet,
            mnemonic: Self.mnemonic
        ))
        XCTAssertEqual(wallet.chainAccounts, [malformed])
    }

    func testAppOwnedUpgradeRejectsBitcoinFromDifferentPhrase() throws {
        let chainSpecificMnemonic = Self.mnemonic
        let rootMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: chainSpecificMnemonic
        )
        let originalBitcoin = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))

        XCTAssertThrowsError(
            try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
                to: wallet,
                mnemonic: rootMnemonic
            )
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletRootRecoveryError,
                .existingAccountUsesDifferentPhrase
            )
        }
        XCTAssertEqual(wallet.chainAccounts, [originalBitcoin])
    }

    func testAppOwnedUpgradeRejectsTairaFromDifferentPhrase() throws {
        let chainSpecificMnemonic = Self.mnemonic
        let rootMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: chainSpecificMnemonic
        )
        let originalTaira = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))

        XCTAssertThrowsError(
            try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
                to: wallet,
                mnemonic: rootMnemonic
            )
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletRootRecoveryError,
                .existingAccountUsesDifferentPhrase
            )
        }
        XCTAssertEqual(wallet.chainAccounts, [originalTaira])
    }

    func testAutomaticAppOwnedProvisioningNeverReplacesMalformedExistingRows() throws {
        let malformedBitcoin = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: Data(repeating: 3, count: 33),
            publicKey: Data(repeating: 3, count: 33),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let malformedTaira = ChainAccountModel(
            chainId: UniversalWalletRegistry.taira.chainId,
            accountId: Data(repeating: 4, count: 32),
            publicKey: Data(repeating: 4, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(
            with: [malformedBitcoin, malformedTaira]
        )

        XCTAssertThrowsError(
            try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
                to: wallet,
                mnemonic: Self.mnemonic
            )
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletRootRecoveryError,
                .existingAccountUsesDifferentPhrase
            )
        }
        XCTAssertEqual(wallet.chainAccounts, [malformedBitcoin, malformedTaira])
    }

    func testAutomaticUpgradePreservesImportedAccountsAndAddsOnlyMissingNetworks() throws {
        let imported = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
            mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let upgraded = try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(
            to: imported, mnemonic: Self.mnemonic
        )
        XCTAssertTrue(imported.chainAccounts.isSubset(of: upgraded.chainAccounts))
        XCTAssertEqual(upgraded.substrateAccountId, imported.substrateAccountId)
        XCTAssertEqual(upgraded.substratePublicKey, imported.substratePublicKey)
        XCTAssertEqual(upgraded.ethereumAddress, imported.ethereumAddress)
        XCTAssertEqual(upgraded.ethereumPublicKey, imported.ethereumPublicKey)
        XCTAssertEqual(upgraded.chainAccounts.count, imported.chainAccounts.count + 1)
        let taira = try XCTUnwrap(upgraded.chainAccounts.first {
            $0.chainId == UniversalWalletRegistry.taira.chainId
        })
        XCTAssertEqual(taira.publicKey, try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic).publicKey)
        XCTAssertEqual(
            try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(to: upgraded, mnemonic: Self.mnemonic),
            upgraded
        )
    }

    func testAutomaticUpgradeKeepsMalformedExistingRowsWithoutBlockingOtherNetworks() throws {
        let existing = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.id,
            accountId: Data(repeating: 3, count: 32),
            publicKey: Data(repeating: 3, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(with: [existing])
        let upgraded = try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(to: wallet, mnemonic: Self.mnemonic)
        XCTAssertTrue(upgraded.chainAccounts.contains(existing))
        XCTAssertEqual(upgraded.chainAccounts.count, 2)
        XCTAssertEqual(try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(to: upgraded, mnemonic: Self.mnemonic), upgraded)
    }

    func testTairaProvisioningDoesNotReplaceDedicatedAccountFromAnotherPhrase() throws {
        let original = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        XCTAssertThrowsError(try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(to: original, mnemonic: Self.mnemonic))
        let upgraded = try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(to: original, mnemonic: Self.mnemonic)
        XCTAssertTrue(original.chainAccounts.isSubset(of: upgraded.chainAccounts))
        XCTAssertEqual(upgraded.chainAccounts.count, original.chainAccounts.count + 1)
    }

    func testTairaProductionChainIsEnabledRankedTestnetWithCanonicalXOR() throws {
        let chain = UniversalWalletRegistry.tairaChainModel
        let asset = try XCTUnwrap(chain.assets.first)
        let node = try XCTUnwrap(chain.nodes.first)

        XCTAssertEqual(chain.chainId, UniversalWalletRegistry.taira.chainId)
        XCTAssertFalse(chain.disabled)
        XCTAssertNotNil(chain.rank)
        XCTAssertTrue(chain.options?.contains(.testnet) == true)
        XCTAssertEqual(asset.id, UniversalWalletRegistry.tairaNativeXorAssetDefinitionId)
        XCTAssertEqual(asset.currencyId, UniversalWalletRegistry.tairaNativeXorAlias)
        XCTAssertEqual(asset.symbol, "XOR")
        XCTAssertEqual(asset.precision, 28)
        XCTAssertTrue(asset.isUtility)
        XCTAssertTrue(asset.isNative)
        XCTAssertEqual(node.url, UniversalWalletRegistry.taira.toriiBaseURL)
        XCTAssertTrue(ChainModelMapper.isNodeCompatibleWithRuntime(node, for: chain))
        XCTAssertTrue(UniversalWalletRegistry.appOwnedProductionChains.contains(chain))
    }

    func testTairaDetailsExposeReceiveAddressButHideSend() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: Self.mnemonic
        )
        let chainAsset = ChainAsset(
            chain: UniversalWalletRegistry.tairaChainModel,
            asset: try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.assets.first)
        )
        let viewModel = ChainAccountViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        ).buildChainAccountViewModel(
            chainAsset: chainAsset,
            wallet: wallet,
            mode: .extended
        )

        XCTAssertNotNil(viewModel.address)
        XCTAssertFalse(viewModel.sendButtonVisible)
        XCTAssertFalse(viewModel.optionsButtonVisible)
    }

    func testMalformedLegacyBitcoinAccountNeverFallsBackToSubstrateAddress() throws {
        let malformedAccount = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: Data(repeating: 0x01, count: 32),
            publicKey: Data(repeating: 0x01, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(
            with: [malformedAccount]
        )
        let viewModel = ChainAccountViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        ).buildChainAccountViewModel(
            chainAsset: ChainAsset(
                chain: UniversalWalletRegistry.bitcoinMainnetChainModel,
                asset: try XCTUnwrap(
                    UniversalWalletRegistry.bitcoinMainnetChainModel.assets.first
                )
            ),
            wallet: wallet,
            mode: .simple
        )

        XCTAssertNil(viewModel.address)
    }

    func testBitcoinProductionChainIsEnabledRankedAndUsesHTTPSIndexer() throws {
        let chain = UniversalWalletRegistry.bitcoinMainnetChainModel
        let asset = try XCTUnwrap(chain.assets.first)
        let node = try XCTUnwrap(chain.nodes.first)

        XCTAssertEqual(chain.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
        XCTAssertFalse(chain.disabled)
        XCTAssertNotNil(chain.rank)
        XCTAssertEqual(asset.id, "BTC")
        XCTAssertEqual(asset.symbol, "BTC")
        XCTAssertEqual(asset.precision, 8)
        XCTAssertTrue(asset.isUtility)
        XCTAssertTrue(asset.isNative)
        XCTAssertEqual(asset.icon, UniversalWalletRegistry.bitcoinIconURL)
        XCTAssertEqual(asset.color, "F7931A")
        XCTAssertEqual(chain.icon, UniversalWalletRegistry.bitcoinIconURL)
        XCTAssertEqual(UniversalWalletRegistry.bitcoinIconURL.host, "bitcoin.org")
        let bitcoinImage = RemoteImageViewModel(url: UniversalWalletRegistry.bitcoinIconURL)
        XCTAssertNotNil(bitcoinImage.fallbackImage)
        XCTAssertNil(bitcoinImage.imageSource.url)
        if case .provider = bitcoinImage.imageSource {} else {
            XCTFail("Bitcoin artwork must load from the bundled image provider")
        }
        let legacyBitcoinImage = RemoteImageViewModel(
            url: UniversalWalletRegistry.legacyBitcoinIconURL
        )
        XCTAssertNotNil(legacyBitcoinImage.fallbackImage)
        if case .provider = legacyBitcoinImage.imageSource {} else {
            XCTFail("Persisted pre-upgrade Bitcoin artwork must use the bundled provider")
        }
        let unrelatedURL = URL(string: "https://example.com/unrelated.svg")!
        XCTAssertEqual(RemoteImageViewModel(url: unrelatedURL).imageSource.url, unrelatedURL)
        let detailViewModel = ChainAccountViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        ).buildChainAccountViewModel(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: AccountGenerator.generateMetaAccount(),
            mode: .extended
        )
        XCTAssertFalse(detailViewModel.optionsButtonVisible)
        let detailLayout = ChainAccountViewLayout(frame: .zero)
        detailLayout.bind(viewModel: detailViewModel)
        XCTAssertTrue(detailLayout.optionsButton.isHidden)
        XCTAssertEqual(node.url, UniversalWalletRegistry.bitcoinMainnetIndexerBaseURL)
        XCTAssertEqual(chain.nodes.map(\.url), [UniversalWalletRegistry.bitcoinMainnetIndexerBaseURL])
        XCTAssertTrue(ChainModelMapper.isNodeCompatibleWithRuntime(node, for: chain))
    }

    func testRootMnemonicAutomaticallyDerivesStandardAppOwnedAccounts() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let rootMnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let keystore = DictionaryKeystore(
            keys: [
                fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): rootMnemonic.entropy()
            ]
        )
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        let mnemonic = try XCTUnwrap(provider.rootMnemonic(for: wallet))
        let provisioned = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: mnemonic
        )
        let bitcoinAddress = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.bitcoinMainnetChainModel,
                wallet: provisioned
            )
        )
        let tairaAddress = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: UniversalWalletRegistry.tairaChainModel,
                wallet: provisioned
            )
        )

        XCTAssertEqual(bitcoinAddress, "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu")
        XCTAssertTrue(tairaAddress.hasPrefix("test"))
        XCTAssertEqual(mnemonic, rootMnemonic.toString())
        XCTAssertEqual(
            try provider.mnemonic(
                for: provisioned,
                chain: UniversalWalletRegistry.bitcoinMainnetChainModel
            ),
            mnemonic
        )
    }

    func testMarkedRawWalletSeedDeterministicallyBridgesToRecoverableAppOwnedMnemonic() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let walletSeed = Data(repeating: 0, count: 32)
        let keystore = DictionaryKeystore(
            keys: [
                fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId): walletSeed,
                fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId):
                    Data(UniversalWalletSeedBridge.contract.utf8)
            ]
        )
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        let expectedMnemonic = String(
            repeating: "abandon ",
            count: 23
        ) + "art"
        XCTAssertEqual(
            try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed),
            expectedMnemonic
        )
        XCTAssertEqual(try provider.rootMnemonic(for: wallet), expectedMnemonic)
    }

    func testCanonicalAccountUsesRootBeforeLegacyAccountEntropy() throws {
        let rootMnemonic = try IRMnemonicCreator().mnemonic(fromList: Self.mnemonic)
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: rootMnemonic.toString()
        )
        let bitcoinAccount = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let accountEntropyTag = fearless.KeystoreTagV2.entropyTagForMetaId(
            wallet.metaId,
            accountId: bitcoinAccount.accountId
        )
        let provider = KeychainUniversalWalletMnemonicProvider(
            keystore: DictionaryKeystore(
                keys: [
                    fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId):
                        rootMnemonic.entropy()
                ],
                errors: [accountEntropyTag: KeystoreError.unexpectedFail]
            )
        )

        XCTAssertEqual(
            try provider.mnemonic(
                for: wallet,
                chain: UniversalWalletRegistry.bitcoinMainnetChainModel
            ),
            rootMnemonic.toString()
        )
    }

    func testUnmarkedLegacySeedNeverSilentlyChangesUniversalWalletIdentity() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let provider = KeychainUniversalWalletMnemonicProvider(
            keystore: DictionaryKeystore(
                keys: [
                    fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId):
                        Data(repeating: 0, count: 32)
                ]
            )
        )

        XCTAssertNil(try provider.rootMnemonic(for: wallet))
    }

    func testMissingRootEntropyAndWalletSeedRemainAccountless() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let provider = KeychainUniversalWalletMnemonicProvider(
            keystore: DictionaryKeystore(keys: [:])
        )

        XCTAssertNil(try provider.rootMnemonic(for: wallet))
    }

    func testWalletSeedKeychainFailureDoesNotLookLikeMissingSecret() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let seedTag = fearless.KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId)
        let sourceTag = fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
        let provider = KeychainUniversalWalletMnemonicProvider(
            keystore: DictionaryKeystore(
                keys: [sourceTag: Data(UniversalWalletSeedBridge.contract.utf8)],
                errors: [seedTag: KeystoreError.unexpectedFail]
            )
        )

        XCTAssertThrowsError(try provider.rootMnemonic(for: wallet)) { error in
            guard case KeystoreError.unexpectedFail = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testWalletSeedSourceMarkerKeychainFailureFailsClosed() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let sourceTag = fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId)
        let provider = KeychainUniversalWalletMnemonicProvider(
            keystore: DictionaryKeystore(
                keys: [:],
                errors: [sourceTag: KeystoreError.unexpectedFail]
            )
        )

        XCTAssertThrowsError(try provider.rootMnemonic(for: wallet)) { error in
            guard case KeystoreError.unexpectedFail = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testWalletSeedBridgeRejectsUnsupportedSeedLength() {
        XCTAssertThrowsError(
            try UniversalWalletSeedBridge.mnemonic(
                fromWalletSeed: Data(repeating: 0x01, count: 31)
            )
        ) { error in
            XCTAssertEqual(
                error as? UniversalWalletSeedBridge.BridgeError,
                .invalidWalletSeedLength
            )
        }
    }

    func testUnexpectedKeychainFailureDoesNotLookLikeMissingMnemonic() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let entropyTag = fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        let keystore = DictionaryKeystore(
            keys: [:],
            errors: [entropyTag: KeystoreError.unexpectedFail]
        )
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        XCTAssertThrowsError(try provider.rootMnemonic(for: wallet)) { error in
            guard case KeystoreError.unexpectedFail = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testChainAccountKeychainFailureDoesNotFallBackToDifferentRootMnemonic() throws {
        let accountMnemonic = Self.mnemonic
        let rootMnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: accountMnemonic
        )
        let bitcoinAccount = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let accountEntropyTag = fearless.KeystoreTagV2.entropyTagForMetaId(
            wallet.metaId,
            accountId: bitcoinAccount.accountId
        )
        let keystore = DictionaryKeystore(
            keys: [
                fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): rootMnemonic.entropy()
            ],
            errors: [accountEntropyTag: KeystoreError.unexpectedFail]
        )
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        XCTAssertThrowsError(
            try provider.mnemonic(
                for: wallet,
                chain: UniversalWalletRegistry.bitcoinMainnetChainModel
            )
        ) { error in
            guard case KeystoreError.unexpectedFail = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testMissingChainEntropyDoesNotPairImportedBitcoinAccountWithDifferentRootMnemonic() throws {
        let importedMnemonic = Self.mnemonic
        let rootMnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: importedMnemonic
        )
        let keystore = DictionaryKeystore(
            keys: [
                fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): rootMnemonic.entropy()
            ]
        )
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        XCTAssertNil(
            try provider.mnemonic(
                for: wallet,
                chain: UniversalWalletRegistry.bitcoinMainnetChainModel
            )
        )
    }

    func testMismatchedChainEntropyNeverDrivesImportedBitcoinAccountDiscovery() throws {
        let importedMnemonic = Self.mnemonic
        let mismatchedMnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: importedMnemonic
        )
        let bitcoinAccount = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let keystore = DictionaryKeystore(
            keys: [
                fearless.KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: bitcoinAccount.accountId
                ): mismatchedMnemonic.entropy()
            ]
        )
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        XCTAssertNil(
            try provider.mnemonic(
                for: wallet,
                chain: UniversalWalletRegistry.bitcoinMainnetChainModel
            )
        )
    }

    func testUnknownUniversalChainNeverAcceptsUnverifiedMnemonic() throws {
        let chainId = "unknown:universal"
        let publicKey = Data(repeating: 0x42, count: 32)
        let wallet = walletWithChainAccount(
            chainId: chainId,
            publicKey: publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: Self.mnemonic)
        let keystore = DictionaryKeystore(
            keys: [
                fearless.KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: publicKey
                ): mnemonic.entropy()
            ]
        )
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        XCTAssertNil(
            try provider.mnemonic(
                for: wallet,
                chain: Self.chain(chainId)
            )
        )
    }

    func testBitcoinNeverUsesGenericSubstrateMissingAccountCreation() {
        XCTAssertFalse(
            MissingAccountFetcher.supportsGenericChainAccountCreation(
                for: UniversalWalletRegistry.bitcoinMainnetChainModel
            )
        )
        let walletActions = WalletDetailsPresenter.baseActions(
            for: UniversalWalletRegistry.bitcoinMainnetChainModel
        )
        XCTAssertEqual(walletActions.count, 1)
        if case .copyAddress = walletActions[0] {} else {
            XCTFail("Bitcoin wallet details must offer copy address first")
        }

        let accountActions = ChainAccountPresenter.baseActions(
            for: UniversalWalletRegistry.bitcoinMainnetChainModel
        )
        XCTAssertTrue(accountActions.isEmpty)
    }

    func testBitcoinRecipientValidationUsesNativeNetworkAndDetectsOwnAddress() throws {
        let mainnetChain = UniversalWalletRegistry.bitcoinMainnetChainModel
        let ownKey = try BitcoinKeyDerivation.deriveKey(
            mnemonic: Self.mnemonic,
            derivationPath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
            network: .mainnet
        )
        let wallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            publicKey: ownKey.publicKey
        )
        let recipient = "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m"
        let testnetAddress = try BitcoinKeyDerivation.deriveKey(
            mnemonic: Self.mnemonic,
            derivationPath: UniversalWalletDerivationPaths.bitcoinTestnetFirstReceive,
            network: .testnet
        ).address
        let testnetChain = Self.chain(
            UniversalWalletRegistry.bitcoinTestnet.chainId
        )

        XCTAssertEqual(
            AddressChainDefiner.validateUniversalAddress(
                recipient,
                for: mainnetChain,
                wallet: wallet
            ),
            .valid(recipient)
        )
        XCTAssertEqual(
            AddressChainDefiner.validateUniversalAddress(
                ownKey.address,
                for: mainnetChain,
                wallet: wallet
            ),
            .sameAddress(ownKey.address)
        )
        XCTAssertEqual(
            AddressChainDefiner.validateUniversalAddress(
                testnetAddress,
                for: mainnetChain,
                wallet: wallet
            ),
            .invalid(testnetAddress)
        )
        XCTAssertEqual(
            AddressChainDefiner.validateUniversalAddress(
                testnetAddress,
                for: testnetChain,
                wallet: wallet
            ),
            .valid(testnetAddress)
        )
        let badChecksum = String(recipient.dropLast()) + (recipient.last == "q" ? "p" : "q")
        XCTAssertEqual(
            AddressChainDefiner.validateUniversalAddress(
                badChecksum,
                for: mainnetChain,
                wallet: wallet
            ),
            .invalid(badChecksum)
        )
        let mixedCase = "B" + recipient.dropFirst()
        XCTAssertEqual(
            AddressChainDefiner.validateUniversalAddress(
                mixedCase,
                for: mainnetChain,
                wallet: wallet
            ),
            .invalid(mixedCase)
        )
        XCTAssertEqual(
            try BitcoinTransactionBuilder.normalizeP2wpkhAddress(
                recipient.uppercased(),
                network: .mainnet
            ),
            recipient
        )
        XCTAssertEqual(
            try BitcoinTransactionBuilder.normalizeP2wpkhAddress(
                " \n\(recipient)\t ",
                network: .mainnet
            ),
            recipient
        )
        XCTAssertEqual(
            WalletSendConfirmPresenter.senderAddress(
                for: mainnetChain,
                wallet: wallet
            ),
            ownKey.address
        )
    }

    func testBitcoinBIP39UsesNFKDForNonASCIIWordsAndPassphrase() throws {
        let composedMnemonic = "éclair éclair éclair éclair éclair éclair éclair éclair éclair éclair éclair éclair"
        let decomposedMnemonic = composedMnemonic.decomposedStringWithCompatibilityMapping
        let compatibilityPassphrase = "㍍ガバヴァぱばぐゞちぢ十人十色"
        let normalizedPassphrase = compatibilityPassphrase.decomposedStringWithCompatibilityMapping

        XCTAssertEqual(
            try BitcoinKeyDerivation.deriveAccount(
                mnemonic: composedMnemonic,
                passphrase: compatibilityPassphrase
            ),
            try BitcoinKeyDerivation.deriveAccount(
                mnemonic: decomposedMnemonic,
                passphrase: normalizedPassphrase
            )
        )
    }

    func testResolvesSolanaMainnetAddressFromMatchingChainAccountPublicKey() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaMainnet.chainId),
            wallet: wallet
        )

        XCTAssertEqual(address, account.address)
    }

    func testResolvesSolanaDevnetAddressFromMatchingChainAccountPublicKey() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaDevnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaDevnet.chainId),
            wallet: wallet
        )

        XCTAssertEqual(address, account.address)
    }

    func testSolanaAddressResolutionFailsClosedWithoutMatchingChainAccount() {
        let wallet = AccountGenerator.generateMetaAccount()

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaMainnet.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testResolvesRealTonMainnetAddressFromMatchingChainAccountPublicKey() throws {
        let account = try TonKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: TonChainSelection.mainnetChainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(TonChainSelection.mainnetChainId),
            wallet: wallet
        )

        XCTAssertEqual(address, account.addressNonBounceable)
    }

    func testTonAddressResolutionRejectsMissingMalformedAndTestnetAccounts() throws {
        XCTAssertNil(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(TonChainSelection.mainnetChainId),
                wallet: AccountGenerator.generateMetaAccount()
            )
        )

        let malformed = walletWithChainAccount(
            chainId: TonChainSelection.mainnetChainId,
            publicKey: Data(repeating: 1, count: 31),
            cryptoType: CryptoType.ed25519.rawValue
        )
        XCTAssertNil(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(TonChainSelection.mainnetChainId),
                wallet: malformed
            )
        )

        let account = try TonKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let testnetOnly = walletWithChainAccount(
            chainId: TonChainSelection.testnetChainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )
        XCTAssertNil(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(TonChainSelection.mainnetChainId),
                wallet: testnetOnly
            )
        )
    }

    func testSolanaAddressResolutionRejectsMalformedPublicKey() {
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: Data(repeating: 0x01, count: 31),
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaMainnet.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testResolverMatchesCanonicalSolanaAccountWhenChainUsesRegistryId() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaMainnet.id),
            wallet: wallet
        )

        XCTAssertEqual(address, account.address)
    }

    func testResolvesTairaI105AddressFromMatchingChainAccountPublicKey() throws {
        let account = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.taira.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(UniversalWalletRegistry.taira.chainId),
                wallet: wallet
            )
        )

        XCTAssertTrue(address.hasPrefix("test"))
        XCTAssertEqual(
            try IrohaAddressCodec.parse(
                address,
                expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            ).publicKeyHex,
            account.publicKeyHex
        )
    }

    func testResolvesNexusI105AddressFromSamePublicKeyWithNexusDiscriminant() throws {
        let account = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.nexus.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(UniversalWalletRegistry.nexus.chainId),
                wallet: wallet
            )
        )

        XCTAssertTrue(address.hasPrefix("sora"))
        XCTAssertEqual(
            try IrohaAddressCodec.parse(
                address,
                expectedDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
            ).publicKeyHex,
            account.publicKeyHex
        )
        XCTAssertThrowsError(
            try IrohaAddressCodec.parse(
                address,
                expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            )
        )
    }

    func testIrohaAddressResolutionFailsClosedWithoutMatchingChainAccount() {
        let wallet = AccountGenerator.generateMetaAccount()

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.taira.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testIrohaAddressResolutionRejectsMalformedPublicKey() {
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.taira.chainId,
            publicKey: Data(repeating: 0x01, count: 31),
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.taira.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testFetchFailsClosedForUniversalWalletChainWithoutMatchingChainAccount() {
        let wallet = AccountGenerator.generateMetaAccount()

        XCTAssertNil(wallet.fetch(for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId).accountRequest()))
        XCTAssertNil(wallet.fetch(for: Self.chain(UniversalWalletRegistry.solanaMainnet.chainId).accountRequest()))
        XCTAssertNil(wallet.fetch(for: Self.chain(UniversalWalletRegistry.taira.chainId).accountRequest()))
        XCTAssertNil(wallet.fetch(for: Self.chain(TonChainSelection.mainnetChainId).accountRequest()))
    }

    func testFetchMatchesRegistryIdToCanonicalUniversalWalletChainAccount() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let response = try XCTUnwrap(
            wallet.fetch(for: Self.chain(UniversalWalletRegistry.solanaMainnet.id).accountRequest())
        )

        XCTAssertEqual(response.chainId, UniversalWalletRegistry.solanaMainnet.id)
        XCTAssertEqual(response.toAddress(), account.address)
    }

    func testChainAccountResponseDerivesUniversalWalletNativeAddresses() throws {
        let bitcoinKey = try BitcoinKeyDerivation.deriveKey(
            mnemonic: Self.mnemonic,
            derivationPath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
            network: .mainnet
        )
        let bitcoinWallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            publicKey: bitcoinKey.publicKey
        )
        XCTAssertEqual(
            bitcoinWallet.fetch(for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId).accountRequest())?.toAddress(),
            bitcoinKey.address
        )

        let irohaAccount = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let irohaWallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.nexus.chainId,
            publicKey: irohaAccount.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )
        let irohaAddress = try XCTUnwrap(
            irohaWallet.fetch(for: Self.chain(UniversalWalletRegistry.nexus.id).accountRequest())?.toAddress()
        )
        XCTAssertEqual(
            try IrohaAddressCodec.parse(
                irohaAddress,
                expectedDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
            ).publicKeyHex,
            irohaAccount.publicKeyHex
        )
    }

    func testAccountFetchingFindsUniversalWalletByNativeAddressOnlyOnMatchingChain() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        var result: Result<ChainAccountResponse?, Error>?
        let found = AccountFetchingHarness().fetchChainAccountFor(
            meta: wallet,
            chain: Self.chain(UniversalWalletRegistry.solanaMainnet.id),
            address: account.address
        ) { result = $0 }

        XCTAssertTrue(found)
        XCTAssertEqual(try result?.get()?.toAddress(), account.address)
    }

    func testAccountFetchingDoesNotExposeUniversalWalletAccountAsSubstrate() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )
        let substrateChain = Self.chain(String(repeating: "a", count: 64))
        let substrateFormattedSolanaKey = try account.publicKey.toAddress(
            using: .substrate(substrateChain.addressPrefix)
        )

        var result: Result<ChainAccountResponse?, Error>?
        let found = AccountFetchingHarness().fetchChainAccountFor(
            meta: wallet,
            chain: substrateChain,
            address: substrateFormattedSolanaKey
        ) { result = $0 }

        XCTAssertFalse(found)
        XCTAssertThrowsError(try result?.get())
    }

    func testNonBitcoinChainsKeepExistingAddressResolution() {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = Self.chain(String(repeating: "0", count: 64))

        let address = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet)

        XCTAssertEqual(address, wallet.fetch(for: chain.accountRequest())?.toAddress())
    }

    private func walletWithBitcoinAccount(chainId: String, publicKey: Data) -> MetaAccountModel {
        walletWithChainAccount(
            chainId: chainId,
            publicKey: publicKey,
            cryptoType: CryptoType.ecdsa.rawValue
        )
    }

    private func walletWithChainAccount(chainId: String, publicKey: Data, cryptoType: UInt8) -> MetaAccountModel {
        let account = ChainAccountModel(
            chainId: chainId,
            accountId: publicKey,
            publicKey: publicKey,
            cryptoType: cryptoType,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [account])
    }

    fileprivate static func chain(_ chainId: String) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Test",
            assets: [],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "https://node.example")!,
                    name: "Test",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            icon: nil,
            options: nil,
            externalApi: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private static let mnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
}

private final class AccountFetchingHarness: AccountFetching {}

private final class DictionaryKeystore: KeystoreProtocol {
    private var keys: [String: Data]
    private let errors: [String: Error]

    init(keys: [String: Data], errors: [String: Error] = [:]) {
        self.keys = keys
        self.errors = errors
    }

    func addKey(_ data: Data, with tag: String) throws {
        keys[tag] = data
    }

    func updateKey(_ data: Data, with tag: String) throws {
        keys[tag] = data
    }

    func fetchKey(for tag: String) throws -> Data {
        if let error = errors[tag] {
            throw error
        }
        guard let data = keys[tag] else {
            throw KeystoreError.noKeyFound
        }
        return data
    }

    func checkKey(for tag: String) throws -> Bool {
        keys[tag] != nil
    }

    func deleteKey(for tag: String) throws {
        keys[tag] = nil
    }
}


// Public upstream TonSwift test vector; no user wallet material.
enum LegacyNativeTonFixture {
    static let phrase = "cluster notice abandon frost gospel boring element situate click mix vague replace imitate garment useful crater resource dose tenant theme foam ancient phrase slight"
    static func account() throws -> LegacyTonAccount {
        let key = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: phrase.components(separatedBy: " "))
        let address = try WalletV4R2(publicKey: key.publicKey.data).address()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try LegacyTonAccount(serializedAddress: encoder.encode(address), publicKey: key.publicKey.data, contractVersion: "v4R2")
    }
    static func privateKey() throws -> Data {
        try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: phrase.components(separatedBy: " ")).privateKey.data
    }
    static func wallet() throws -> fearless.MetaAccountModel {
        fearless.MetaAccountModel(metaId: "legacy-native-ton-fixture", name: "Released native TON", substrateAccountId: nil,
            substrateCryptoType: CryptoType.ed25519.rawValue, substratePublicKey: nil, ethereumAddress: nil, ethereumPublicKey: nil,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: true, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: "-239", assetsVisibility: [],
            hasBackup: false, favouriteChainIds: [], legacyTonAccount: try account())
    }
}

final class LegacyNativeTonUpgradeTests: XCTestCase {
    func testReleasedNativeTonProductionSendRequiresQuoteAndSignsOriginalAccount() async throws {
        let native = try LegacyNativeTonFixture.account()
        let secret = try LegacyNativeTonFixture.privateKey()
        let remote = LegacyTonTestRemote()
        let journal = TonKeychainPendingIntentJournal(keystore: DictionaryKeystore(keys: [:]))
        let coordinator = TonPendingIntentCoordinator(journal: journal)
        let service = TonSendService(remote: remote, pendingCoordinator: coordinator, clock: { 1_700_000_000 })
        let request = TonNativeEstimateRequest(publicKey: native.publicKey, senderAddress: native.address,
            recipientAddress: "EQAimhPwOYc5Z1JP_pddxo82SHOl67T0Lklw91pKtSX2Q094", amountNanotons: "1000000", bounce: true)
        var requestedSecret = false
        do {
            _ = try await service.send(request, feeQuote: nil, legacyAccount: native) {
                requestedSecret = true
                return TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: secret)
            }
            XCTFail("Fresh legacy send must require a confirmed quote")
        } catch {
            XCTAssertEqual(error as? TonSendServiceError, .feeQuoteRequired)
        }
        XCTAssertFalse(requestedSecret)
        let emptyBroadcasts = await remote.broadcasts
        XCTAssertTrue(emptyBroadcasts.isEmpty)
        let quote = try await service.quote(request)
        let result = try await service.send(request, feeQuote: quote, legacyAccount: native) {
            TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: secret)
        }
        let signed = result.prepared.signedMessage
        XCTAssertEqual(signed.publicKey, native.publicKey)
        XCTAssertEqual(signed.walletAddress, native.address)
        XCTAssertEqual(signed.signingPayloadHashHex, quote.unsignedMessage.signingPayloadHashHex)
        let broadcasts = await remote.broadcasts
        let emulated = await remote.signedEmulations
        XCTAssertEqual(broadcasts, [signed.boc])
        XCTAssertEqual(emulated, broadcasts)
        let senderRaw = try TonSwift.Address.parse(native.address).toRaw()
        XCTAssertEqual(try journal.load(senderRaw: senderRaw)?.message.boc, signed.boc)
        try await service.acknowledgeConfirmedTransfer(senderAddress: native.address,
            identity: TonTransferIntentIdentity(request: request), messageHashHex: result.messageHashHex)
        XCTAssertNil(try journal.load(senderRaw: senderRaw))
    }

    func testNativeWalletHasNoSubstrateIdentityAndKeepsExactJSONAcrossEditsAndCodable() throws {
        let wallet = try LegacyNativeTonFixture.wallet()
        let changed = wallet.replacingName("Renamed").replacingCurrency(wallet.selectedCurrency)
            .replacingChainAccounts([]).replacingIsBackuped(true).replacingFavoutites(["-239"])
        XCTAssertNil(changed.substrateAccountId)
        XCTAssertNil(changed.substratePublicKey)
        XCTAssertNil(changed.utilsModel)
        XCTAssertEqual(changed.legacyTonAccount, wallet.legacyTonAccount)
        XCTAssertEqual(try JSONDecoder().decode(fearless.MetaAccountModel.self, from: JSONEncoder().encode(changed)), changed)
        let request = UniversalWalletAccountAddressResolverTests.chain("-239").accountRequest()
        let account = try XCTUnwrap(changed.fetch(for: request))
        XCTAssertFalse(account.isChainAccount)
        XCTAssertEqual(account.accountId, wallet.legacyTonAccount?.serializedAddress)
        XCTAssertEqual(account.toAddress(), wallet.legacyTonAccount?.address)
        XCTAssertNil(changed.fetch(for: UniversalWalletAccountAddressResolverTests.chain("ordinary-substrate").accountRequest()))
        XCTAssertTrue(UniversalWalletChainAccountSupport.hasValidDedicatedAccount(in: changed, for: "ton-mainnet"))
    }

    func testNativeAddressCodecReadsReleasedJSONWithoutChangingWorkchainOrHash() throws {
        let native = try LegacyNativeTonFixture.account()
        let parsed = try TonSwift.Address.parse(accountId: native.serializedAddress, workchainId: 0)
        XCTAssertEqual(parsed.toString(bounceable: false), native.address)
        XCTAssertEqual(parsed.hash, try TonAddressCodec.v4R2AccountHash(publicKey: native.publicKey))
        XCTAssertThrowsError(try TonSwift.Address.parse(accountId: Data(repeating: 1, count: 36), workchainId: 0))
    }

    func testExistingMnemonicExportFlowReturnsTheOriginalNativePhraseForWalletAndAddress() throws {
        let wallet = try LegacyNativeTonFixture.wallet()
        let native = try XCTUnwrap(wallet.legacyTonAccount)
        let chain = UniversalWalletAccountAddressResolverTests.chain("-239")
        let keys = DictionaryKeystore(keys: [fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): Data(LegacyNativeTonFixture.phrase.utf8)])
        let interactor = ExportMnemonicInteractor(keystore: keys,
            repository: AccountRepositoryFactory(storageFacade: UserDataStorageTestFacade()).createMetaAccountRepository(for: nil, sortDescriptors: []),
            operationManager: OperationManager())
        let output = LegacyTonExportOutput()
        interactor.presenter = output
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        interactor.fetchExportDataForWallet(wallet: wallet, accounts: [ChainAccountInfo(chain: chain, account: account)])
        XCTAssertNil(output.error)
        XCTAssertEqual(output.models.map { $0.mnemonic.toString() }, [LegacyNativeTonFixture.phrase])
        let completed = expectation(description: "native TON address phrase export")
        output.completion = { completed.fulfill() }
        interactor.fetchExportDataForAddress(native.address, chain: chain, wallet: wallet)
        wait(for: [completed], timeout: 10)
        XCTAssertNil(output.error)
        XCTAssertEqual(output.models.map { $0.mnemonic.toString() }, [LegacyNativeTonFixture.phrase])
        XCTAssertTrue(output.models.allSatisfy { $0.derivationPath == nil })
    }

    func testNativeEntropyExportsExactPhraseAndDoesNotUseBIP39() throws {
        let native = try LegacyNativeTonFixture.account()
        let stored = Data(LegacyNativeTonFixture.phrase.utf8)
        let mnemonic = try native.mnemonic(from: stored)
        XCTAssertEqual(mnemonic.entropy(), stored)
        XCTAssertEqual(mnemonic.toString(), LegacyNativeTonFixture.phrase)
        XCTAssertEqual(mnemonic.numberOfWords(), 24)
        XCTAssertEqual(mnemonic.word(at: 0), "cluster")
        let uppercase = Data(LegacyNativeTonFixture.phrase.uppercased().utf8)
        XCTAssertEqual(try native.mnemonic(from: uppercase).entropy(), uppercase)
        XCTAssertThrowsError(try IRMnemonicCreator().mnemonic(fromEntropy: stored))
        let wallet = try LegacyNativeTonFixture.wallet()
        let keys = DictionaryKeystore(keys: [fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): stored])
        XCTAssertEqual(AvailableExportOptionsProvider(keystore: keys).getAvailableExportOptions(for: wallet, accountId: nil), [.mnemonic])
        XCTAssertNil(try KeychainUniversalWalletMnemonicProvider(keystore: keys).rootMnemonic(for: wallet))
        XCTAssertEqual(try UniversalWalletStoredSeedAdopter(keystore: keys).adoptStoredSecret(for: wallet), wallet)
        XCTAssertEqual(try keys.fetchKey(for: fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId)), stored)
    }

    func testHistoricalPrivateKeyTagWorksWithoutPhraseAndNativePhraseIsSafeFallback() throws {
        let native = try LegacyNativeTonFixture.account()
        let wallet = try LegacyNativeTonFixture.wallet()
        let secret = try LegacyNativeTonFixture.privateKey()
        let tag = fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)
        XCTAssertEqual(tag, wallet.metaId + "-tonSecretKey")
        let keyOnly = DictionaryKeystore(keys: [tag: secret])
        XCTAssertEqual(try native.signingCredentials(keystore: keyOnly, metaId: wallet.metaId).legacyNativePrivateKey, secret)
        let phraseOnly = DictionaryKeystore(keys: [fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): Data(LegacyNativeTonFixture.phrase.utf8)])
        XCTAssertEqual(try native.signingCredentials(keystore: phraseOnly, metaId: wallet.metaId).legacyNativePrivateKey, secret)
        XCTAssertFalse(try phraseOnly.checkKey(for: tag))
    }

    func testCorruptExistingKeyDoesNotFallBackSilentlyAndMismatchedPhraseCannotExport() throws {
        let native = try LegacyNativeTonFixture.account()
        let wallet = try LegacyNativeTonFixture.wallet()
        let keys = DictionaryKeystore(keys: [fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId): Data(repeating: 1, count: 64),
            fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId): Data(LegacyNativeTonFixture.phrase.utf8)])
        XCTAssertThrowsError(try native.signingCredentials(keystore: keys, metaId: wallet.metaId))
        XCTAssertThrowsError(try native.mnemonic(from: Data(Array(repeating: "abandon", count: 24).joined(separator: " ").utf8)))
        XCTAssertThrowsError(try LegacyTonAccount(serializedAddress: native.serializedAddress, publicKey: Data(repeating: 1, count: 32), contractVersion: "v4R2"))
        XCTAssertThrowsError(try LegacyTonAccount(serializedAddress: native.serializedAddress, publicKey: native.publicKey, contractVersion: "v5R1"))
    }

    func testNativeSigningMatchesReleasedV4R2KeyAndBindsSenderBeforeRemoteUse() throws {
        let native = try LegacyNativeTonFixture.account()
        let secret = try LegacyNativeTonFixture.privateKey()
        let request = TonNativeSendRequest(mnemonic: "", senderAddress: native.address,
            recipientAddress: native.address, amountNanotons: "1", bounce: false, legacyNativePrivateKey: secret)
        let derived = try TonKeyDerivation.signingAccount(for: request)
        XCTAssertEqual(derived.publicKey, native.publicKey)
        XCTAssertEqual(derived.privateKey, secret.prefix(32))
        let invalid = TonNativeSendRequest(mnemonic: "", senderAddress: "UQDnBF4JTFKHTYjulEJyNd4dstLGH1m51UrLdu01_tw4zz3r",
            recipientAddress: native.address, amountNanotons: "1", bounce: false, legacyNativePrivateKey: secret)
        XCTAssertThrowsError(try TonKeyDerivation.signingAccount(for: invalid))
    }
}


private actor LegacyTonTestRemote: TonTransferRemoteProtocol {
    nonisolated let reviewedSignedOperationOrigin: String? = "https://tonapi.io"
    var broadcasts: [Data] = []
    var signedEmulations: [Data] = []
    func jettonWallet(ownerAddress: String, assetAddress: String, amount: String, precision: Int) async throws -> TonResolvedJettonWallet {
        TonResolvedJettonWallet(masterAddress: "0:" + String(repeating: "11", count: 32),
            walletAddress: "0:" + String(repeating: "22", count: 32))
    }
    func walletState(address: String) async throws -> TonWalletRemoteState {
        TonWalletRemoteState(sequenceNumber: 7, isInitialized: true)
    }
    func recipientRequiresMemo(address: String) async throws -> Bool { false }
    func emulateUnsigned(message: TonUnsignedEmulationMessage, intent: TonEmulationIntent) async throws -> TonEmulationResult {
        TonEmulationResult(accepted: true, totalFeeNanotons: 1000)
    }
    func emulateSigned(message: TonSignedExternalMessage, intent: TonEmulationIntent) async throws -> TonEmulationResult {
        signedEmulations.append(message.boc)
        return TonEmulationResult(accepted: true, totalFeeNanotons: 1000)
    }
    func broadcast(message: TonSignedExternalMessage) async throws { broadcasts.append(message.boc) }
    func reconcile(message: TonSignedExternalMessage, intent: TonEmulationIntent) async throws -> TonReconciliationResult { .confirmed }
}


private final class LegacyTonExportOutput: ExportMnemonicInteractorOutputProtocol {
    var models: [ExportMnemonicData] = []
    var error: Error?
    var completion: (() -> Void)?
    func didReceive(exportDatas: [ExportMnemonicData]) { models = exportDatas; completion?() }
    func didReceive(error: Error) { self.error = error; completion?() }
}

final class TonLegacyJettonTransferTests: XCTestCase {
    private static let master = "0:" + String(repeating: "11", count: 32)
    private static let tokenWallet = "0:" + String(repeating: "22", count: 32)
    private static let recipient = "0:229a13f039873967524ffe975dc68f364873a5ebb4f42e4970f75a4ab525f643"
    private static let now: UInt64 = 1_700_000_000

    private func request(amount: String = "123456789", master: String = TonLegacyJettonTransferTests.master, comment: String? = nil) throws -> TonNativeEstimateRequest {
        let native = try LegacyNativeTonFixture.account()
        let jetton = try TonJettonTransferDetails(masterAddress: master, recipientAddress: Self.recipient, amount: amount)
        return TonNativeEstimateRequest(asset: .jetton(masterAddress: master), publicKey: native.publicKey,
            senderAddress: native.address, recipientAddress: Self.tokenWallet,
            amountNanotons: TonJettonTransferDetails.attachedNanotons, bounce: true, comment: comment, jetton: jetton)
    }

    private func transaction(_ request: TonNativeEstimateRequest, attached: String? = nil, bounce: Bool = true) -> TonTransferTransactionRequest {
        TonTransferTransactionRequest(asset: request.asset, senderAddress: request.senderAddress,
            recipientAddress: request.recipientAddress, amountNanotons: attached ?? request.amountNanotons,
            sequenceNumber: 7, includeStateInit: false, validUntil: Self.now + 120,
            bounce: bounce, comment: request.comment, jetton: request.jetton)
    }

    func testTEP74BodyMatchesIndependentTonCoreVectorsAndOriginalNativeSigningKey() throws {
        for (comment, expected) in [(nil, "88ee2c7542a0714f64dd42e77e9039232bb218a9bca55b9f67f73c98dc1ffa52"),
            ("legacy memo", "92f866f987062297fe69b19677dcad0438c7ffdff935d3acae79ce787f6fb2eb")] as [(String?, String)] {
            let input = try request(comment: comment)
            let signed = try TonTransferTransactionBuilder.buildAndSign(request: transaction(input),
                privateKeySeed: LegacyNativeTonFixture.privateKey().prefix(32), now: Self.now)
            let inspected = try TonTransferTransactionBuilder.inspectSignedMessage(signed.boc)
            XCTAssertEqual(inspected.messageBodyHashHex, expected)
            XCTAssertEqual(inspected.recipientAddress, Self.tokenWallet)
            XCTAssertEqual(inspected.amountNanotons, "640000000")
            XCTAssertEqual(signed.publicKey, try LegacyNativeTonFixture.account().publicKey)
            XCTAssertEqual(try TonEmulationIntent(request: input).messageBodyHashHex, expected)
        }
    }

    func testJettonTransferCannotChangeAttachmentBounceAssetOrRecipientToBypassIntent() throws {
        let input = try request()
        let secret = try LegacyNativeTonFixture.privateKey().prefix(32)
        for invalid in [transaction(input, attached: "1"), transaction(input, bounce: false)] {
            XCTAssertThrowsError(try TonTransferTransactionBuilder.buildAndSign(request: invalid, privateKeySeed: secret, now: Self.now))
        }
        for amount in ["0", "-1", "001", String(repeating: "9", count: 38)] {
            XCTAssertThrowsError(try request(amount: amount))
        }
        let invalid = TonNativeEstimateRequest(asset: .jetton(masterAddress: Self.tokenWallet), publicKey: input.publicKey,
            senderAddress: input.senderAddress, recipientAddress: input.recipientAddress, amountNanotons: input.amountNanotons,
            bounce: true, jetton: input.jetton)
        XCTAssertThrowsError(try TonTransferIntentIdentity(request: invalid))
        let selfTransfer = try TonJettonTransferDetails(masterAddress: Self.master, recipientAddress: input.senderAddress, amount: "1")
        let selfRequest = TonTransferTransactionRequest(asset: input.asset, senderAddress: input.senderAddress,
            recipientAddress: input.recipientAddress, amountNanotons: input.amountNanotons, sequenceNumber: 7,
            validUntil: Self.now + 120, bounce: true, comment: nil, jetton: selfTransfer)
        XCTAssertThrowsError(try TonTransferTransactionBuilder.buildAndSign(request: selfRequest, privateKeySeed: secret, now: Self.now))
    }

    func testJettonQuoteJournalAndRetryBindExactAssetAndRetainOriginalBearer() async throws {
        let native = try LegacyNativeTonFixture.account()
        let input = try request()
        let remote = LegacyTonTestRemote()
        let journal = TonKeychainPendingIntentJournal(keystore: DictionaryKeystore(keys: [:]))
        let service = TonSendService(remote: remote, pendingCoordinator: TonPendingIntentCoordinator(journal: journal), clock: { Self.now })
        let quote = try await service.quote(input)
        XCTAssertEqual(quote.requiredTonNanotons, 640_001_000)
        let anotherAmount = try await service.quote(request(amount: "123456788"))
        let anotherMaster = try await service.quote(request(master: "0:" + String(repeating: "33", count: 32)))
        XCTAssertNotEqual(quote.quoteIDHex, anotherAmount.quoteIDHex)
        XCTAssertNotEqual(quote.quoteIDHex, anotherMaster.quoteIDHex)
        XCTAssertEqual(quote.intent.messageBodyHashHex, anotherMaster.intent.messageBodyHashHex,
            "Master identity is quote-bound even though TEP-74 encodes its wallet, not master")
        do {
            _ = try await service.send(input, feeQuote: anotherAmount, legacyAccount: native) {
                TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
            }
            XCTFail("A quote for another token amount must not sign")
        } catch { XCTAssertEqual(error as? TonSendServiceError, .feeQuoteMismatch) }
        let before = await remote.signedEmulations
        XCTAssertTrue(before.isEmpty)
        let sent = try await service.send(input, feeQuote: quote, legacyAccount: native) {
            TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
        }
        let sender = try TonSwift.Address.parse(native.address).toRaw()
        let stored = try XCTUnwrap(journal.load(senderRaw: sender))
        let record = try TonPendingIntentJournalCodec.encode(stored)
        XCTAssertEqual(try TonPendingIntentJournalCodec.decode(record, expectedSenderRaw: sender), stored)
        let text = String(decoding: record, as: UTF8.self)
        XCTAssertFalse(text.contains(LegacyNativeTonFixture.phrase))
        XCTAssertTrue(text.contains("\"jettonAmount\":\"123456789\""))
        let altered = Data(text.replacingOccurrences(of: "\"jettonAmount\":\"123456789\"", with: "\"jettonAmount\":\"123456788\"").utf8)
        XCTAssertThrowsError(try TonPendingIntentJournalCodec.decode(altered, expectedSenderRaw: sender))
        let recovered = TonSendService(remote: remote, pendingCoordinator: TonPendingIntentCoordinator(journal: journal), clock: { Self.now + 500 })
        let resolved = try await recovered.resolveJettonWallet(ownerAddress: native.address, assetAddress: Self.master,
            recipientAddress: Self.recipient, amount: "123456789", precision: 9)
        XCTAssertEqual(resolved.walletAddress, Self.tokenWallet)
        let replay = try await recovered.send(input, feeQuote: nil, legacyAccount: native) {
            XCTFail("Persisted bearer recovery must not access a secret")
            throw TonSendServiceError.invalidAccount
        }
        XCTAssertEqual(replay.prepared.signedMessage.boc, sent.prepared.signedMessage.boc)
        let broadcasts = await remote.broadcasts
        XCTAssertEqual(broadcasts.count, 1)
        try await recovered.acknowledgeConfirmedTransfer(senderAddress: native.address,
            identity: TonTransferIntentIdentity(request: input), messageHashHex: replay.messageHashHex)
        XCTAssertNil(try journal.load(senderRaw: sender))
    }

    func testJettonRoutingRecognizesHistoricalWalletAndCurrentMasterAssetIdentifiersOnlyForNativeLegacyWallet() throws {
        let chain = UniversalWalletAccountAddressResolverTests.chain("-239")
        for identifier in [Self.master, Self.tokenWallet] {
            let asset = AssetModel(id: identifier, name: "Synthetic token", symbol: "TEST", precision: 9,
                icon: nil, price: nil, fiatDayChange: nil, currencyId: identifier, existentialDeposit: nil,
                color: nil, isUtility: false, isNative: false, staking: nil, purchaseProviders: nil,
                type: .xcm, ethereumType: nil, priceProvider: nil, coingeckoPriceId: nil)
            let chainAsset = ChainAsset(chain: chain, asset: asset)
            XCTAssertTrue(TonTransferService.supportsAsset(chainAsset, allowLegacyJettons: true))
            XCTAssertFalse(TonTransferService.supportsAsset(chainAsset, allowLegacyJettons: false))
        }
    }

    func testLegacyJettonWalletFlowRequiresRenderedFeeAndSubmitsExactTokenIntent() async throws {
        let wallet = try LegacyNativeTonFixture.wallet()
        let chain = UniversalWalletAccountAddressResolverTests.chain("-239")
        let asset = AssetModel(id: Self.master, name: "Synthetic token", symbol: "TEST", precision: 9,
            icon: nil, price: nil, fiatDayChange: nil, currencyId: Self.master, existentialDeposit: nil,
            color: nil, isUtility: false, isNative: false, staking: nil, purchaseProviders: nil,
            type: .xcm, ethereumType: nil, priceProvider: nil, coingeckoPriceId: nil)
        let transfer = Transfer(chainAsset: ChainAsset(chain: chain, asset: asset), amount: BigUInt(123456789),
            receiver: Self.recipient, tip: nil, appId: nil)
        let keystore = DictionaryKeystore(keys: [fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId): try LegacyNativeTonFixture.privateKey()])
        let remote = LegacyTonTestRemote()
        let service = TonTransferService(wallet: wallet, chain: chain, remote: remote,
            mnemonicProvider: KeychainUniversalWalletMnemonicProvider(keystore: keystore),
            pendingCoordinator: TonPendingIntentCoordinator(journal: TonKeychainPendingIntentJournal(keystore: keystore)),
            clock: { Self.now })
        let ready = expectation(description: "token fee presented")
        let listener = LegacyJettonFeeListener { ready.fulfill() }
        service.subscribeForFee(transfer: transfer, listener: listener)
        await fulfillment(of: [ready], timeout: 10)
        XCTAssertNil(listener.error)
        let fee = try XCTUnwrap(listener.fee), id = try XCTUnwrap(listener.id)
        XCTAssertEqual(fee, BigUInt(640_001_000))
        let wrongFeeAccepted = await service.confirmFeePresentation(id: id, fee: 1)
        XCTAssertFalse(wrongFeeAccepted)
        let acknowledged = await service.confirmFeePresentation(id: id, fee: fee)
        XCTAssertTrue(acknowledged)
        let hash = try await service.submit(transfer: transfer)
        let sent = await remote.broadcasts
        XCTAssertEqual(sent.count, 1)
        let body = try TonTransferTransactionBuilder.inspectSignedMessage(XCTUnwrap(sent.first))
        XCTAssertEqual(body.recipientAddress, Self.tokenWallet)
        XCTAssertEqual(body.messageBodyHashHex, "88ee2c7542a0714f64dd42e77e9039232bb218a9bca55b9f67f73c98dc1ffa52")
        let completed = await service.acknowledgeSubmittedTransfer(hash: hash, transfer: transfer)
        XCTAssertTrue(completed)
    }

    func testReviewedJettonOwnerLookupAcceptsBothHistoricalAndMasterIdsAndRejectsChangedPrecision() async throws {
        let native = try LegacyNativeTonFixture.account()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LegacyJettonURLProtocol.self]
        LegacyJettonURLProtocol.response = try JSONSerialization.data(withJSONObject: ["balances": [[
            "balance": "999999999", "wallet_address": Self.account(Self.tokenWallet), "jetton": Self.preview
        ]]])
        let remote = TonAPIRemoteClient(factory: TonAPIClientFactory(tonAPIURL: URL(string: "https://tonapi.io")!, token: "public-synthetic-test"), configuration: configuration)
        for id in [Self.master, Self.tokenWallet] {
            let resolved = try await remote.jettonWallet(ownerAddress: native.address, assetAddress: id, amount: "123456789", precision: 9)
            XCTAssertEqual(resolved, TonResolvedJettonWallet(masterAddress: Self.master, walletAddress: Self.tokenWallet))
        }
        do {
            _ = try await remote.jettonWallet(ownerAddress: native.address, assetAddress: Self.master, amount: "1", precision: 6)
            XCTFail("Token precision changes must not reinterpret the approved amount")
        } catch { XCTAssertEqual(error as? TonTransferTransactionBuilderError, .unsupportedAsset) }
    }

    func testRealGeneratedTonAPITransportAcceptsLinkedJettonTraceAndRejectsAdditionalTokenRisk() async throws {
        let input = try request()
        let signed = try TonTransferTransactionBuilder.buildAndSign(request: transaction(input),
            privateKeySeed: LegacyNativeTonFixture.privateKey().prefix(32), now: Self.now)
        let intent = try TonEmulationIntent(request: input)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LegacyJettonURLProtocol.self]
        let remote = TonAPIRemoteClient(factory: TonAPIClientFactory(tonAPIURL: URL(string: "https://tonapi.io")!, token: "public-synthetic-test"), configuration: configuration)
        var fixture = try consequences(signed: signed, intent: intent)
        LegacyJettonURLProtocol.response = try JSONSerialization.data(withJSONObject: fixture)
        let accepted = try await remote.emulateSigned(message: signed, intent: intent)
        XCTAssertTrue(accepted.accepted)
        var risk = try XCTUnwrap(fixture["risk"] as? [String: Any])
        var quantities = try XCTUnwrap(risk["jettons"] as? [[String: Any]])
        quantities.append(quantities[0]); risk["jettons"] = quantities; fixture["risk"] = risk
        LegacyJettonURLProtocol.response = try JSONSerialization.data(withJSONObject: fixture)
        let rejected = try await remote.emulateSigned(message: signed, intent: intent)
        XCTAssertFalse(rejected.accepted)
    }

    private static func account(_ raw: String) -> [String: Any] {
        ["address": raw, "is_scam": false, "is_wallet": true]
    }
    private static var preview: [String: Any] {
        ["address": master, "name": "Synthetic token", "symbol": "TEST", "decimals": 9,
         "image": "https://fixture.invalid/token.png", "verification": "none"]
    }
    private func consequences(signed: TonSignedExternalMessage, intent: TonEmulationIntent) throws -> [String: Any] {
        let envelope = try Message.loadFrom(slice: Cell.fromBoc(src: signed.boc)[0].beginParse())
        let internalMessage = try MessageRelaxed.loadFrom(slice: envelope.body.refs[0].beginParse())
        let sender = Self.account(intent.senderAddress), token = Self.account(Self.tokenWallet)
        func message(external: Bool, source: [String: Any]?, destination: [String: Any], value: Int64, body: String, lt: Int64) -> [String: Any] {
            var result: [String: Any] = ["msg_type": external ? "ext_in_msg" : "int_msg", "created_lt": lt,
                "ihr_disabled": true, "bounce": !external, "bounced": false, "value": value,
                "fwd_fee": 1, "ihr_fee": 0, "destination": destination, "import_fee": 0, "created_at": 1, "raw_body": body]
            if let source { result["source"] = source }; return result
        }
        let incoming = message(external: true, source: nil, destination: sender, value: 0, body: try envelope.body.toBoc().hexString(), lt: 1)
        let outgoing = message(external: false, source: sender, destination: token, value: intent.amountNanotons, body: try internalMessage.body.toBoc().hexString(), lt: 2)
        func transaction(account: [String: Any], inbound: [String: Any], outputs: [[String: Any]]) -> [String: Any] {
            ["hash": "fixture-transaction", "lt": 2, "account": account, "success": true, "utime": Self.now,
             "orig_status": "active", "end_status": "active", "total_fees": 1000, "transaction_type": "TransOrd",
             "state_update_old": "old", "state_update_new": "new", "in_msg": inbound, "out_msgs": outputs,
             "block": "(-1,8000000000000000,1)", "aborted": false, "destroyed": false,
             "compute_phase": ["skipped": false, "success": true, "gas_fees": 1, "gas_used": 1, "vm_steps": 1, "exit_code": 0],
             "action_phase": ["success": true, "total_actions": outputs.count, "skipped_actions": 0, "fwd_fees": 1, "total_fees": 1]]
        }
        let child: [String: Any] = ["transaction": transaction(account: token, inbound: outgoing, outputs: []), "interfaces": ["jetton_wallet"], "emulated": true]
        let trace: [String: Any] = ["transaction": transaction(account: sender, inbound: incoming, outputs: [outgoing]),
            "interfaces": ["wallet_v4r2"], "emulated": true, "children": [child]]
        return ["trace": trace, "risk": ["transfer_all_remaining_balance": false, "ton": intent.amountNanotons,
            "jettons": [["quantity": "123456789", "wallet_address": token, "jetton": Self.preview]], "nfts": []],
            "event": ["event_id": "fixture-event", "timestamp": Self.now, "account": sender, "is_scam": false,
                "lt": 2, "in_progress": false, "extra": 0, "actions": [["type": "JettonTransfer", "status": "ok",
                    "simple_preview": ["name": "Token transfer", "description": "Public synthetic fixture", "accounts": [sender]],
                    "JettonTransfer": ["sender": sender, "recipient": Self.account(Self.recipient), "senders_wallet": Self.tokenWallet,
                        "recipients_wallet": "0:" + String(repeating: "44", count: 32), "amount": "123456789", "jetton": Self.preview]]]]]
    }
}

private final class LegacyJettonURLProtocol: URLProtocol {
    static var response = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, url.host == "tonapi.io", let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.response)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class LegacyJettonFeeListener: TonTransferFeePresentationListener {
    var fee: BigUInt?
    var id: String?
    var error: Error?
    let completion: () -> Void
    init(completion: @escaping () -> Void) { self.completion = completion }
    func didReceiveTonFee(fee: BigUInt, presentationID: String) { self.fee = fee; id = presentationID; completion() }
    func didReceiveFee(fee: BigUInt) { self.fee = fee; completion() }
    func didReceiveFeeError(feeError: Error) { error = feeError; completion() }
}


final class TonConnectTransferBoundaryTests: XCTestCase {
    private let now: UInt64 = 1_700_000_000
    private let recipient = "0:" + String(repeating: "22", count: 32)

    private func request(network: TonTransferNetwork = .mainnet, replay: String = "session/rpc-1") throws -> TonConnectTransferRequest {
        let native = try LegacyNativeTonFixture.account()
        return try TonConnectTransferRequest(publicKey: native.publicKey, senderAddress: native.address, network: network,
            validUntil: now + 1000, replayIdentifier: replay, messages: [
                TonConnectTransferMessage(recipientAddress: recipient, amountNanotons: "123"),
                TonConnectTransferMessage(recipientAddress: native.address, amountNanotons: "0")
            ])
    }

    func testQuoteSendRestartAndIdempotentAcknowledgementRetainExactBearer() async throws {
        let request = try request()
        let native = try LegacyNativeTonFixture.account()
        let keys = DictionaryKeystore(keys: [:])
        let journal = TonKeychainPendingIntentJournal(keystore: keys)
        let remote = TonConnectBoundaryRemote()
        let service = TonSendService(remote: remote, pendingCoordinator: TonPendingIntentCoordinator(journal: journal), clock: { self.now })
        let quote = try await service.quoteTonConnect(request)
        XCTAssertFalse(quote.effectDescriptions.isEmpty)
        XCTAssertEqual(quote.requiredTonNanotons, 1123)
        let result = try await service.sendTonConnect(request, feeQuote: quote, legacyAccount: native) {
            TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
        }
        let identity = try TonTransferIntentIdentity(request: request.estimateRequest)
        let persisted = try XCTUnwrap(journal.load(senderRaw: identity.coordinationKey))
        XCTAssertEqual(persisted.message.boc, result.prepared.signedMessage.boc)
        XCTAssertEqual(persisted.feeQuote?.executionEffects, quote.executionEffects)
        let encoded = try TonPendingIntentJournalCodec.encode(persisted)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(LegacyNativeTonFixture.phrase))
        let restarted = TonSendService(remote: remote, pendingCoordinator: TonPendingIntentCoordinator(journal: journal), clock: { self.now + 2000 })
        let recovered = try await restarted.sendTonConnect(request, feeQuote: nil, legacyAccount: native) {
            XCTFail("Recovery must not read or recreate a key")
            throw TonSendServiceError.invalidAccount
        }
        XCTAssertEqual(recovered, result)
        let calls = await remote.counts()
        XCTAssertEqual(calls.broadcast, 1)
        XCTAssertEqual(calls.signed, 1)
        try await restarted.acknowledgeTonConnect(request: request, messageHashHex: result.messageHashHex)
        try await restarted.acknowledgeTonConnect(request: request, messageHashHex: result.messageHashHex)
        XCTAssertNil(try journal.load(senderRaw: identity.coordinationKey))
    }

    func testAcknowledgingOldCachedReplyLeavesNewerPendingRequestUntouched() async throws {
        let journal = TonInMemoryPendingIntentJournal()
        let remote = TonConnectBoundaryRemote()
        let service = TonSendService(remote: remote, pendingCoordinator: TonPendingIntentCoordinator(journal: journal), clock: { self.now })
        let first = try request(replay: "session/first")
        let native = try LegacyNativeTonFixture.account()
        let firstQuote = try await service.quoteTonConnect(first)
        let firstResult = try await service.sendTonConnect(first, feeQuote: firstQuote, legacyAccount: native) {
            TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
        }
        try await service.acknowledgeTonConnect(request: first, messageHashHex: firstResult.messageHashHex)
        await remote.setSequenceNumber(8)
        let second = try request(replay: "session/second")
        let secondQuote = try await service.quoteTonConnect(second)
        let secondResult = try await service.sendTonConnect(second, feeQuote: secondQuote, legacyAccount: native) {
            TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
        }
        XCTAssertNotEqual(firstResult.messageHashHex, secondResult.messageHashHex)
        try await service.acknowledgeTonConnect(request: first, messageHashHex: firstResult.messageHashHex)
        XCTAssertEqual(try journal.load(senderRaw: first.senderAddress)?.message.messageHashHex, secondResult.messageHashHex)
    }

    func testReplayIdentityAndEveryMessageAreBoundToQuote() async throws {
        let first = try request()
        let second = try request(replay: "session/rpc-2")
        let remote = TonConnectBoundaryRemote()
        let service = TonSendService(remote: remote, pendingCoordinator: TonPendingIntentCoordinator(journal: TonInMemoryPendingIntentJournal()), clock: { self.now })
        let quote = try await service.quoteTonConnect(first)
        let secondQuote = try await service.quoteTonConnect(second)
        XCTAssertNotEqual(quote.quoteIDHex, secondQuote.quoteIDHex)
        XCTAssertEqual(quote.unsignedMessage.boc, secondQuote.unsignedMessage.boc)
        do {
            _ = try await service.sendTonConnect(second, feeQuote: quote, legacyAccount: LegacyNativeTonFixture.account()) {
                TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
            }
            XCTFail("A reply-loss retry identity cannot borrow another RPC's quote")
        } catch { XCTAssertEqual(error as? TonSendServiceError, .feeQuoteMismatch) }
        let calls = await remote.counts()
        XCTAssertEqual(calls.signed, 0)
        XCTAssertEqual(calls.broadcast, 0)
    }

    func testTestnetUsesExplicitOriginAndSeparatePendingNamespace() async throws {
        let keys = DictionaryKeystore(keys: [:])
        let journal = TonKeychainPendingIntentJournal(keystore: keys)
        let coordinator = TonPendingIntentCoordinator(journal: journal)
        var results: [(TonSendService, TonConnectTransferRequest, TonSentTransferTransaction)] = []
        for network in [TonTransferNetwork.mainnet, .testnet] {
            let request = try request(network: network)
            let remote = TonConnectBoundaryRemote(network: network)
            let service = TonSendService(remote: remote, pendingCoordinator: coordinator, clock: { self.now })
            let quote = try await service.quoteTonConnect(request)
            XCTAssertEqual(quote.transactionRequest.network, network)
            let result = try await service.sendTonConnect(request, feeQuote: quote, legacyAccount: LegacyNativeTonFixture.account()) {
                TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
            }
            results.append((service, request, result))
        }
        for (_, request, result) in results {
            let identity = try TonTransferIntentIdentity(request: request.estimateRequest)
            XCTAssertEqual(try journal.load(senderRaw: identity.coordinationKey)?.message.messageHashHex, result.messageHashHex)
        }
        try await results[0].0.acknowledgeTonConnect(request: results[0].1, messageHashHex: results[0].2.messageHashHex)
        let testIdentity = try TonTransferIntentIdentity(request: results[1].1.estimateRequest)
        XCTAssertNotNil(try journal.load(senderRaw: testIdentity.coordinationKey))
        let wrong = TonSendService(remote: TonConnectBoundaryRemote(), pendingCoordinator: coordinator, clock: { self.now })
        do { _ = try await wrong.quoteTonConnect(results[1].1); XCTFail("Wrong network") }
        catch { XCTAssertEqual(error as? TonSendServiceError, .untrustedFeeQuoteEndpoint) }
    }

    func testChangedEffectsAfterSignatureKeepPendingAndDoNotBroadcast() async throws {
        let request = try request()
        let journal = TonInMemoryPendingIntentJournal()
        let remote = TonConnectBoundaryRemote(changedEffects: true, confirms: false)
        let service = TonSendService(remote: remote, pendingCoordinator: TonPendingIntentCoordinator(journal: journal), clock: { self.now })
        let quote = try await service.quoteTonConnect(request)
        do {
            _ = try await service.sendTonConnect(request, feeQuote: quote, legacyAccount: LegacyNativeTonFixture.account()) {
                TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
            }
            XCTFail("Changed effects must not authorize broadcast")
        } catch {
            guard case .broadcastOutcomeUnknown = error as? TonSendServiceError else { return XCTFail("Unexpected \(error)") }
        }
        let counts = await remote.counts()
        XCTAssertEqual(counts.signed, 1)
        XCTAssertEqual(counts.broadcast, 0)
        XCTAssertNotNil(try journal.load(senderRaw: request.senderAddress))
    }

    func testJournalWriteFailureCannotExposeSignedBearer() async throws {
        let request = try request()
        let remote = TonConnectBoundaryRemote()
        let service = TonSendService(remote: remote, pendingCoordinator: TonPendingIntentCoordinator(journal: TonConnectFailingJournal()), clock: { self.now })
        let quote = try await service.quoteTonConnect(request)
        do {
            _ = try await service.sendTonConnect(request, feeQuote: quote, legacyAccount: LegacyNativeTonFixture.account()) {
                TonSigningCredentials(mnemonic: "", legacyNativePrivateKey: try LegacyNativeTonFixture.privateKey())
            }
            XCTFail("Unavailable journal")
        } catch { XCTAssertEqual(error as? TonPendingIntentJournalError, .unavailable) }
        let counts = await remote.counts()
        XCTAssertEqual(counts.signed, 0)
        XCTAssertEqual(counts.broadcast, 0)
    }

    func testMalformedInputsAndWrongStateInitFailBeforeSigning() throws {
        let valid = try request()
        XCTAssertThrowsError(try TonConnectTransferRequest(publicKey: valid.publicKey, senderAddress: valid.senderAddress,
            network: .mainnet, validUntil: valid.validUntil, replayIdentifier: "x", messages: Array(repeating: valid.messages[0], count: 5)))
        XCTAssertThrowsError(try TonConnectTransferMessage(recipientAddress: recipient, amountNanotons: "00"))
        let badRoot = Data([0xb5,0xee,0x9c,0x72,1,1,1,1,0,2,1,0,0]).base64EncodedString()
        XCTAssertThrowsError(try TonConnectTransferMessage(recipientAddress: recipient, amountNanotons: "1", payloadBocBase64: badRoot))
        let native = try LegacyNativeTonFixture.account()
        let state = try Builder().store(WalletV4R2(publicKey: native.publicKey).stateInit).endCell().toBoc().base64EncodedString()
        XCTAssertThrowsError(try TonConnectTransferMessage(recipientAddress: recipient, amountNanotons: "1", stateInitBocBase64: state))
        let testRecipient = try TonSwift.Address.parse(raw: recipient).toString(urlSafe: true, testOnly: true, bounceable: false)
        let testMessage = try TonConnectTransferMessage(recipientAddress: testRecipient, amountNanotons: "1")
        XCTAssertThrowsError(try TonConnectTransferRequest(publicKey: valid.publicKey, senderAddress: valid.senderAddress,
            network: .mainnet, validUntil: valid.validUntil, replayIdentifier: "x", messages: [testMessage]))
        XCTAssertNoThrow(try TonConnectTransferRequest(publicKey: valid.publicKey, senderAddress: valid.senderAddress,
            network: .testnet, validUntil: valid.validUntil, replayIdentifier: "x", messages: [testMessage]))
    }
}

private struct TonConnectFailingJournal: TonPendingIntentJournaling {
    func load(senderRaw: String) throws -> TonPendingSignedIntent? { nil }
    func save(_ pending: TonPendingSignedIntent) throws { throw TonPendingIntentJournalError.unavailable }
    func delete(senderRaw: String, expectedMessageHashHex: String) throws {}
}

private actor TonConnectBoundaryRemote: TonTransferRemoteProtocol {
    nonisolated let reviewedSignedOperationOrigin: String?
    let changedEffects: Bool
    let confirms: Bool
    var signed = 0
    var broadcasts = 0
    var sequenceNumber: UInt64 = 7
    func setSequenceNumber(_ value: UInt64) { sequenceNumber = value }
    init(network: TonTransferNetwork = .mainnet, changedEffects: Bool = false, confirms: Bool = true) {
        reviewedSignedOperationOrigin = network == .mainnet ? "https://tonapi.io" : "https://testnet.tonapi.io"
        self.changedEffects = changedEffects
        self.confirms = confirms
    }
    func counts() -> (signed: Int, broadcast: Int) { (signed, broadcasts) }
    func walletState(address: String) async throws -> TonWalletRemoteState { TonWalletRemoteState(sequenceNumber: sequenceNumber, isInitialized: true) }
    func recipientRequiresMemo(address: String) async throws -> Bool { false }
    func emulateUnsigned(message: TonUnsignedEmulationMessage, intent: TonEmulationIntent) async throws -> TonEmulationResult {
        TonEmulationResult(accepted: true, totalFeeNanotons: 1000, executionEffects: try effects(intent, changed: false))
    }
    func emulateSigned(message: TonSignedExternalMessage, intent: TonEmulationIntent) async throws -> TonEmulationResult {
        signed += 1
        return TonEmulationResult(accepted: true, totalFeeNanotons: 1000, executionEffects: try effects(intent, changed: changedEffects))
    }
    func broadcast(message: TonSignedExternalMessage) async throws { broadcasts += 1 }
    func reconcile(message: TonSignedExternalMessage, intent: TonEmulationIntent) async throws -> TonReconciliationResult { confirms ? .confirmed : .notFound }
    private func effects(_ intent: TonEmulationIntent, changed: Bool) throws -> TonConnectExecutionEffects {
        func account(_ address: String) -> [String: Any] { ["address": address, "is_scam": false, "is_wallet": true] }
        let action: [String: Any] = ["type": "TonTransfer", "status": "ok",
            "TonTransfer": ["sender": account(intent.senderAddress), "recipient": account(intent.recipientAddress), "amount": changed ? 999 : 123],
            "simple_preview": ["name": "TON transfer", "description": "Synthetic reviewed transfer", "value": "0.000000123 TON", "accounts": []]]
        let decoded = try JSONDecoder().decode([Components.Schemas.Action].self, from: JSONSerialization.data(withJSONObject: [action]))
        return try TonConnectExecutionEffects(actions: decoded)
    }
}


final class TonConnectIndependentBuilderTests: XCTestCase {
    func testFourMessagesAndLibraryStateInitMatchTonCore() throws {
        let key = Data(hex: "c893fc0b676782a5c157ad8fddb389f75caba6eea1c198d8075a8a43afce70a9")!
        let publicKey = Data(hex: "34eb4b67d64f74d989ce2bc2e3dfddb7ed4cb0eec92f29fbecd05b1eabab0254")!
        let messages = try [
            TonConnectTransferMessage(recipientAddress: "UQAiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIsAH", amountNanotons: "123", payloadBocBase64: "te6cckEBAQEAEQAAHgAAAABsZWdhY3kgZGFwcDTbzSE="),
            TonConnectTransferMessage(recipientAddress: "0:88bbe439f5a9b598daaf3d183a71b857d6b84fb0614681317012fc1960b5ff8e", amountNanotons: "456", stateInitBocBase64: "te6cckEBAwEALgACATQBAghCAkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCAAgAAAATG6x6GQ=="),
            TonConnectTransferMessage(recipientAddress: "0:dde0c94dfc0e964ca1532865c8952f52cadbcaa3903c135c2ce36f529a308f6c", amountNanotons: "0"),
            TonConnectTransferMessage(recipientAddress: "-1:" + String(repeating: "33", count: 32), amountNanotons: "789")
        ]
        let connect = try TonConnectTransferRequest(publicKey: publicKey, senderAddress: "0:dde0c94dfc0e964ca1532865c8952f52cadbcaa3903c135c2ce36f529a308f6c", network: .mainnet,
                                                     validUntil: 1700001000, replayIdentifier: "public-session/rpc-1", messages: messages)
        XCTAssertEqual(try TonConnectTransferRequest.decodeCanonical(connect.canonicalData()), connect)
        let request = TonTransferTransactionRequest(asset: .tonConnect, senderAddress: connect.senderAddress,
            recipientAddress: messages[0].recipientAddress, amountNanotons: connect.amountNanotons,
            sequenceNumber: 7, validUntil: connect.validUntil, bounce: false, comment: nil, tonConnect: connect)
        let signed = try TonTransferTransactionBuilder.buildAndSign(request: request, privateKeySeed: key, now: 1700000000)
        XCTAssertEqual(signed.messageHashHex, "009c1dedac1cc2880c04ceb33056f7a4f0103e5bc66ed4886413942dd7bb4d56")
        XCTAssertEqual(signed.signingPayloadHashHex, "fdb74a447cbdfddfcb020e714017a1fa214cc17aec892e01c4e0c98f11f110a5")
        let inspected = try TonTransferTransactionBuilder.inspectSignedMessage(signed.boc, tonConnect: connect)
        XCTAssertEqual(inspected.amountNanotons, "1368")
        XCTAssertEqual(inspected.messageBodyHashHex, try connect.bindingHashHex())
        let preview = try TonTransferTransactionBuilder.buildForFeeEstimation(request: request, publicKey: publicKey, now: 1700000000)
        XCTAssertEqual(preview.signingPayloadHashHex, signed.signingPayloadHashHex)
        let rebuilt = try TonTransferTransactionBuilder.rebuildSignedMessage(request: request, publicKey: publicKey,
            signature: inspected.signature, now: 1700000000)
        XCTAssertEqual(rebuilt, signed)
    }
    func testBoundedParserPreservesEveryQualifiedExoticForm() throws {
        XCTAssertEqual(try TonTransferTransactionBuilder.tonConnectBoc("te6cckEBAQEAIwAIQgJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQvb5cRU=").hash, "099af5203b3229b13bbdf0ed6f4bbf597c3d029baa1dd552ed420e77c354b1ab")
        XCTAssertEqual(try TonTransferTransactionBuilder.tonConnectBoc("te6cckEBAwEALgACATQBAghCAkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCAAgAAAATG6x6GQ==").hash, "88bbe439f5a9b598daaf3d183a71b857d6b84fb0614681317012fc1960b5ff8e")
        XCTAssertEqual(try TonTransferTransactionBuilder.tonConnectBoc("te6cckEBAQEAJgAoSAEBEREREREREREREREREREREREREREREREREREREREREREAAeg9pko=").hash, "6539f5f6ad7758f970b0e8b5b51919845089ac2dd34138fe40e684d26b9044e6")
        XCTAssertEqual(try TonTransferTransactionBuilder.tonConnectBoc("te6cckEBAQEASABojAEDERERERERERERERERERERERERERERERERERERERERERESEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEgABAAJ2nvaJ").hash, "7ee2bbd542232c6559b55ad2feb6a5f5b86b34dc17586c0667668e50ecdc8c98")
        XCTAssertEqual(try TonTransferTransactionBuilder.tonConnectBoc("te6cckEBAQEAagDo0AEHERERERERERERERERERERERERERERERERERERERERERESEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhMTExMTExMTExMTExMTExMTExMTExMTExMTExMTExMTAAEAAgADGWyNBg==").hash, "f0dca87f3f068769cf622e9984be868a993681d5981fb708c577de6cc6ab201d")
        XCTAssertEqual(try TonTransferTransactionBuilder.tonConnectBoc("te6cckEBAgEALAAJRgOWN09dJpMHnqld5gjNzJuE7HhfuasRqdH6dFZq1oEaogAAAQAIAAAE0omiECY=").hash, "962e4f5ebfcf28e6d8e934ae70ff7d94150d6d183a774300021d2a3765da0b53")
        XCTAssertEqual(try TonTransferTransactionBuilder.tonConnectBoc("te6cckEBAwEAcgAKigSWN09dJpMHnqld5gjNzJuE7HhfuasRqdH6dFZq1oEaogma9SA7MimxO73w7W9Lv1l8PQKbqh3VUu1CDnfDVLGrAAAAAAECAAgAAATSCEICQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkIEsgC0").hash, "e9cf7ba69dcae4a20ee8bea92dc5b853cec4fa0372e463c015c6516f198f6f88")
        XCTAssertEqual(try TonTransferTransactionBuilder.tonConnectBoc("te6cckEBAgEATABhAgkBaIwBAxEREREREREREREREREREREREREREREREREREREREREREhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEhIAAQACaJ6B+A==").hash, "0dde37cf96f4f6dc7ec8109a0a9ad36ce338075f165c004ff91053d84c9019b2")
    }
}


final class TonConnectGeneratedTransportTests: XCTestCase {
    private let now: UInt64 = 1_700_000_000

    func testGeneratedAPIValidatesEveryMessageAndSameUnsignedSignedEffects() async throws {
        let native = try LegacyNativeTonFixture.account()
        let messages = try [
            TonConnectTransferMessage(recipientAddress: "0:" + String(repeating: "22", count: 32), amountNanotons: "123"),
            TonConnectTransferMessage(recipientAddress: "0:" + String(repeating: "33", count: 32), amountNanotons: "456")
        ]
        let connect = try TonConnectTransferRequest(publicKey: native.publicKey, senderAddress: native.address,
            network: .mainnet, validUntil: now + 1000, replayIdentifier: "generated/rpc-1", messages: messages)
        let request = TonTransferTransactionRequest(asset: .tonConnect, senderAddress: connect.senderAddress,
            recipientAddress: messages[0].recipientAddress, amountNanotons: connect.amountNanotons,
            sequenceNumber: 7, validUntil: connect.validUntil, bounce: true, comment: nil, tonConnect: connect)
        let signed = try TonTransferTransactionBuilder.buildAndSign(request: request, privateKeySeed: LegacyNativeTonFixture.privateKey().prefix(32), now: now)
        let unsigned = try TonTransferTransactionBuilder.buildForFeeEstimation(request: request, publicKey: native.publicKey, now: now)
        let intent = try TonEmulationIntent(request: connect.estimateRequest)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TonConnectBoundaryURLProtocol.self]
        let remote = TonAPIRemoteClient(factory: TonAPIClientFactory(tonAPIURL: URL(string: "https://tonapi.io")!, token: "public-synthetic-test"), configuration: configuration)
        let event = try fullEvent(connect)
        let signedTrace = try trace(signed.boc)
        var consequences: [String: Any] = ["trace": signedTrace,
            "risk": ["transfer_all_remaining_balance": false, "ton": 579, "jettons": [], "nfts": []],
            "event": accountEvent(connect, actions: event["actions"]!)]
        TonConnectBoundaryURLProtocol.responses = try [
            "/v2/traces/emulate": JSONSerialization.data(withJSONObject: trace(unsigned.boc)),
            "/v2/events/emulate": JSONSerialization.data(withJSONObject: event),
            "/v2/wallet/emulate": JSONSerialization.data(withJSONObject: consequences)
        ]
        TonConnectBoundaryURLProtocol.observed = []
        let preview = try await remote.emulateUnsigned(message: unsigned, intent: intent)
        let result = try await remote.emulateSigned(message: signed, intent: intent)
        XCTAssertTrue(preview.accepted)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(preview.executionEffects, result.executionEffects)
        XCTAssertEqual(result.executionEffects?.descriptions.count, 2)
        XCTAssertTrue(TonConnectBoundaryURLProtocol.observed.contains { $0.url?.absoluteString.contains("ignore_signature_check=true") == true })
        XCTAssertTrue(TonConnectBoundaryURLProtocol.observed.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer public-synthetic-test" })

        var brokenTrace = signedTrace
        var transaction = try XCTUnwrap(brokenTrace["transaction"] as? [String: Any])
        var out = try XCTUnwrap(transaction["out_msgs"] as? [[String: Any]])
        out[1]["value"] = 999; transaction["out_msgs"] = out; brokenTrace["transaction"] = transaction
        consequences["trace"] = brokenTrace
        TonConnectBoundaryURLProtocol.responses["/v2/wallet/emulate"] = try JSONSerialization.data(withJSONObject: consequences)
        let changedSecond = try await remote.emulateSigned(message: signed, intent: intent)
        XCTAssertFalse(changedSecond.accepted)

        consequences["trace"] = signedTrace
        consequences["risk"] = ["transfer_all_remaining_balance": true, "ton": 579, "jettons": [], "nfts": []]
        TonConnectBoundaryURLProtocol.responses["/v2/wallet/emulate"] = try JSONSerialization.data(withJSONObject: consequences)
        let drainsAll = try await remote.emulateSigned(message: signed, intent: intent)
        XCTAssertFalse(drainsAll.accepted)
    }

    func testOnlyExactNetworkOriginsReceiveSignedOperationCredentials() throws {
        let main = TonAPIClientFactory.canonicalAuthenticatedOrigin
        let test = TonAPIClientFactory.canonicalTestnetOrigin
        XCTAssertEqual(TonAPIClientFactory.reviewedSendNetwork(for: main), .mainnet)
        XCTAssertEqual(TonAPIClientFactory.reviewedSendNetwork(for: test), .testnet)
        XCTAssertTrue(TonAPIClientFactory(tonAPIURL: test, token: "public-synthetic-test").hasReviewedProductionSendCredential)
        for value in ["https://testnet.tonapi.io.evil.invalid", "https://testnet.tonapi.io:444", "http://testnet.tonapi.io", "https://testnet.tonapi.io/v2"] {
            let url = try XCTUnwrap(URL(string: value))
            XCTAssertNil(TonAPIClientFactory.reviewedSendNetwork(for: url))
            XCTAssertFalse(TonAPIClientFactory(tonAPIURL: url, token: "public-synthetic-test").usesAuthorization)
        }
    }

    private func account(_ address: String) -> [String: Any] { ["address": address, "is_scam": false, "is_wallet": true] }

    private func fullEvent(_ connect: TonConnectTransferRequest) throws -> [String: Any] {
        let actions: [[String: Any]] = connect.messages.map { message in
            ["type": "TonTransfer", "status": "ok",
             "TonTransfer": ["sender": account(connect.senderAddress), "recipient": account(message.recipientAddress), "amount": Int64(message.amountNanotons)!],
             "simple_preview": ["name": "TON transfer", "description": "Public synthetic fixture", "accounts": [account(message.recipientAddress)]]]
        }
        return ["event_id": "public-event", "timestamp": now, "actions": actions, "value_flow": [], "is_scam": false, "lt": 2, "in_progress": false, "fees": [:]]
    }

    private func accountEvent(_ connect: TonConnectTransferRequest, actions: Any) -> [String: Any] {
        ["event_id": "public-event", "timestamp": now, "actions": actions, "account": account(connect.senderAddress), "is_scam": false, "lt": 2, "in_progress": false, "extra": 0]
    }

    private func trace(_ boc: Data) throws -> [String: Any] {
        let envelope = try Message.loadFrom(slice: TonTransferTransactionBuilder.parseBoundedBoc(boc).beginParse())
        guard case let .externalInInfo(external) = envelope.info else { throw TonSendServiceError.invalidAccount }
        let sender = external.dest.toRaw()
        func hex(_ cell: Cell) throws -> String { try cell.toBoc().map { String(format: "%02x", $0) }.joined() }
        func msg(_ destination: String, source: String?, amount: Int64, bounce: Bool, body: String, lt: Int64) -> [String: Any] {
            var result: [String: Any] = ["msg_type": source == nil ? "ext_in_msg" : "int_msg", "created_lt": lt, "ihr_disabled": true,
                "bounce": bounce, "bounced": false, "value": amount, "fwd_fee": 1, "ihr_fee": 0,
                "destination": account(destination), "import_fee": 0, "created_at": 1, "raw_body": body]
            if let source { result["source"] = account(source) }
            return result
        }
        func transaction(_ address: String, incoming: [String: Any], outputs: [[String: Any]]) -> [String: Any] {
            ["hash": String(repeating: "ab", count: 32), "lt": 2, "account": account(address), "success": true, "utime": 1,
             "orig_status": "active", "end_status": "active", "total_fees": 1000, "transaction_type": "TransOrd",
             "state_update_old": "old", "state_update_new": "new", "in_msg": incoming, "out_msgs": outputs,
             "block": "(-1,8000000000000000,1)", "aborted": false, "destroyed": false,
             "compute_phase": ["skipped": false, "success": true, "gas_fees": 1, "gas_used": 1, "vm_steps": 1, "exit_code": 0],
             "action_phase": ["success": true, "total_actions": outputs.count, "skipped_actions": 0, "fwd_fees": 1, "total_fees": 1]]
        }
        var outputs: [[String: Any]] = [], children: [[String: Any]] = []
        for (index, cell) in envelope.body.refs.enumerated() {
            let message = try MessageRelaxed.loadFrom(slice: cell.beginParse())
            guard case let .internalInfo(info) = message.info else { throw TonSendServiceError.invalidAccount }
            let outgoing = try msg(info.dest.toRaw(), source: sender, amount: Int64(info.value.coins.rawValue.description)!, bounce: info.bounce,
                                   body: hex(message.body), lt: Int64(index + 2))
            outputs.append(outgoing)
            children.append(["transaction": transaction(info.dest.toRaw(), incoming: outgoing, outputs: []), "interfaces": ["wallet_v4r2"], "emulated": true])
        }
        let incoming = try msg(sender, source: nil, amount: 0, bounce: false, body: hex(envelope.body), lt: 1)
        return ["transaction": transaction(sender, incoming: incoming, outputs: outputs), "interfaces": ["wallet_v4r2"], "emulated": true, "children": children]
    }
}

private final class TonConnectBoundaryURLProtocol: URLProtocol {
    static var responses: [String: Data] = [:]
    static var observed: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, ["tonapi.io", "testnet.tonapi.io"].contains(url.host ?? ""),
              let data = Self.responses[url.path],
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        Self.observed.append(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
