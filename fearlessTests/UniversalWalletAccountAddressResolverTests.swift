import SSFModels
import XCTest
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

    func testBitcoinProvisioningRepairsLegacyGenericAliasAndMismatchedAccounts() throws {
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

        let repaired = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: wallet,
            mnemonic: Self.mnemonic
        )
        let expected = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: Self.mnemonic,
            network: .mainnet
        )
        let bitcoinAccounts = repaired.chainAccounts.filter {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }

        XCTAssertEqual(bitcoinAccounts.count, 1)
        XCTAssertEqual(bitcoinAccounts.first?.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
        XCTAssertEqual(bitcoinAccounts.first?.publicKey, expected.publicKey)
        XCTAssertEqual(bitcoinAccounts.first?.accountId, expected.publicKey)
        XCTAssertEqual(bitcoinAccounts.first?.cryptoType, CryptoType.ecdsa.rawValue)
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

    func testTairaProvisioningRepairsGenericSr25519Account() throws {
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

        let repaired = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: wallet,
            mnemonic: Self.mnemonic
        )
        let accounts = repaired.chainAccounts.filter {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )
        }

        XCTAssertEqual(accounts.count, 1)
        let account = try XCTUnwrap(accounts.first)
        XCTAssertEqual(account.cryptoType, CryptoType.ed25519.rawValue)
        XCTAssertTrue(UniversalWalletChainAccountSupport.isValidTairaAccount(account))
    }

    func testAppOwnedUpgradeAddsTairaWithoutReplacingExistingBitcoinAccount() throws {
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

        let upgraded = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: rootMnemonic
        )
        let upgradedBitcoin = try XCTUnwrap(upgraded.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let taira = try XCTUnwrap(upgraded.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))
        let expectedTaira = try IrohaKeyDerivation.deriveAccount(mnemonic: rootMnemonic)

        XCTAssertEqual(upgradedBitcoin, originalBitcoin)
        XCTAssertEqual(taira.publicKey, expectedTaira.publicKey)
    }

    func testAppOwnedUpgradePreservesValidChainSpecificTairaAccount() throws {
        let chainSpecificMnemonic = Self.mnemonic
        let rootMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: chainSpecificMnemonic
        )
        let originalTaira = try XCTUnwrap(wallet.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))

        let upgraded = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: rootMnemonic
        )
        let upgradedTaira = try XCTUnwrap(upgraded.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.isValidTairaAccount($0)
        }))
        let bitcoin = try XCTUnwrap(upgraded.chainAccounts.first(where: {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            )
        }))
        let expectedBitcoin = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: rootMnemonic,
            network: .mainnet
        )

        XCTAssertEqual(upgradedTaira, originalTaira)
        XCTAssertEqual(bitcoin.publicKey, expectedBitcoin.publicKey)
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
        XCTAssertEqual(asset.precision, 9)
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
        XCTAssertEqual(node.url, UniversalWalletRegistry.bitcoinMainnetIndexerBaseURL)
        XCTAssertTrue(ChainModelMapper.isNodeCompatibleWithRuntime(node, for: chain))
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
        XCTAssertEqual(walletActions.count, 2)
        if case .copyAddress = walletActions[0] {} else {
            XCTFail("Bitcoin wallet details must offer copy address first")
        }
        if case .switchNode = walletActions[1] {} else {
            XCTFail("Bitcoin wallet details must offer switch node second")
        }

        let accountActions = ChainAccountPresenter.baseActions(
            for: UniversalWalletRegistry.bitcoinMainnetChainModel
        )
        XCTAssertEqual(accountActions.count, 1)
        if case .switchNode = accountActions[0] {} else {
            XCTFail("Bitcoin chain account must only offer switch node")
        }
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

    private static func chain(_ chainId: String) -> ChainModel {
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
