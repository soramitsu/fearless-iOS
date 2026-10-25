import BigInt
import CryptoKit
import XCTest
@testable import fearless
import SSFModels

/// IOSUX-6: the one zero rule (root docs/portfolio-contract.md §4) with the iOS hide-while-zero
/// hint, testnets hidden by default and the account setup row for app-owned Bitcoin.
final class PortfolioVisibilityPolicyTests: XCTestCase {
    private static let registrySnapshotSha256 = "fa6f0e23cd87dfb3e5536980591dd22ae30e49bf59d04dc2a0b31fc53237ea66"
    private static let parityCasesSha256 = "aab5746a3bf2aa75d661266c75ebea37138cde8aacd426e08508c06d2e5daa81"

    private var userDefaults: UserDefaults!
    private var suiteName: String!
    private var cachedRegistryChains: [ChainModel]?

    override func setUp() {
        super.setUp()
        suiteName = "PortfolioVisibilityPolicyTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        cachedRegistryChains = nil
        super.tearDown()
    }

    // MARK: - Truth table

    func testExplicitHiddenIsNeverDisplayed() {
        for balanceIsPositive in [false, true] {
            let input = PortfolioVisibilityInput(
                preference: .hidden,
                balanceIsPositive: balanceIsPositive,
                isListedZeroDefault: true,
                isPrimaryUtility: true,
                isFavouriteNetwork: true,
                offersAccountSetup: true
            )
            XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .hidden)
        }
    }

    func testExplicitShownVisibleAtZero() {
        let inputs = [
            PortfolioVisibilityInput(preference: .shown),
            PortfolioVisibilityInput(preference: .shown, isVerified: false),
            PortfolioVisibilityInput(preference: .shown, isTestnet: true),
            PortfolioVisibilityInput(preference: .shown, isSendVetoed: true, isLegacyZeroHidden: true)
        ]

        for input in inputs {
            XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .visible, "\(input)")
        }
    }

    func testExplicitShownWithoutAnAccountHasNoRow() {
        XCTAssertEqual(
            PortfolioVisibilityPolicy.placement(PortfolioVisibilityInput(preference: .shown, hasAccount: false)),
            .zeroCollapsed
        )
        XCTAssertEqual(
            PortfolioVisibilityPolicy.placement(
                PortfolioVisibilityInput(preference: .shown, hasAccount: false, offersAccountSetup: true)
            ),
            .visible
        )
    }

    func testFundedAutoAssetIsVisibleWhateverTheHints() {
        let input = PortfolioVisibilityInput(
            balanceIsPositive: true,
            hasAccount: true,
            isListedZeroDefault: false,
            isSendVetoed: true,
            isLegacyZeroHidden: true
        )

        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .visible)
    }

    func testTestnetAutoHiddenEvenIfRankedOrFunded() {
        for balanceIsPositive in [false, true] {
            let input = PortfolioVisibilityInput(
                balanceIsPositive: balanceIsPositive,
                isTestnet: true,
                isListedZeroDefault: true,
                isPrimaryUtility: true,
                isFavouriteNetwork: true
            )
            XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .hidden)
        }
    }

    func testOnlySelectedTestnetShowsHoldingsButIsNeverAZeroDefault() {
        var input = PortfolioVisibilityInput(
            balanceIsPositive: true,
            isTestnet: true,
            isOnlySelectedNetwork: true,
            isPrimaryUtility: true
        )
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .visible)

        input.balanceIsPositive = false
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .zeroCollapsed)
    }

    func testUnverifiedAutoHoldingIsDetectedAndNeverAZeroRow() {
        XCTAssertEqual(
            PortfolioVisibilityPolicy.placement(PortfolioVisibilityInput(balanceIsPositive: true, isVerified: false)),
            .detected
        )
        XCTAssertEqual(
            PortfolioVisibilityPolicy.placement(
                PortfolioVisibilityInput(isVerified: false, isListedZeroDefault: true, isPrimaryUtility: true)
            ),
            .zeroCollapsed
        )
    }

    func testListedZeroDefaultNeedsAnAccountAndNoVeto() {
        let listed = PortfolioVisibilityInput(isListedZeroDefault: true, isPrimaryUtility: true)
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(listed), .visible)

        var withoutAccount = listed
        withoutAccount.hasAccount = false
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(withoutAccount), .zeroCollapsed)

        var vetoed = listed
        vetoed.isSendVetoed = true
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(vetoed), .zeroCollapsed)
    }

    func testOtherZeroAssetsCollapse() {
        let input = PortfolioVisibilityInput(isListedZeroDefault: false, isPrimaryUtility: false, isFavouriteNetwork: true)

        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .zeroCollapsed)
    }

    func testPrimaryUtilityOfFavouriteOrOnlySelectedNetworkVisibleAtZero() {
        XCTAssertEqual(
            PortfolioVisibilityPolicy.placement(PortfolioVisibilityInput(isPrimaryUtility: true, isFavouriteNetwork: true)),
            .visible
        )
        XCTAssertEqual(
            PortfolioVisibilityPolicy.placement(PortfolioVisibilityInput(isOnlySelectedNetwork: true, isPrimaryUtility: true)),
            .visible
        )
        XCTAssertEqual(
            PortfolioVisibilityPolicy.placement(PortfolioVisibilityInput(isPrimaryUtility: true)),
            .zeroCollapsed
        )
    }

    func testLegacyZeroHiddenPinnedUtilityHiddenAtZeroVisibleWhenFunded() {
        var input = PortfolioVisibilityInput(
            isListedZeroDefault: true,
            isPrimaryUtility: true,
            isFavouriteNetwork: true,
            isLegacyZeroHidden: true
        )
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .zeroCollapsed)

        input.balanceIsPositive = true
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .visible)

        input.balanceIsPositive = false
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .zeroCollapsed, "back at zero, hidden again")
    }

    // MARK: - Context

    /// Contract §4 `walletHoldsAccountFor`: no zero row without an account, Bitcoin included
    /// (critique C2). The row still offers setup, and an explicit Show lists it.
    func testBitcoinAccountlessOffersSetupButIsNoZeroDefault() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let bitcoin = try XCTUnwrap(UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first)

        let input = context(wallet: wallet).input(for: bitcoin)

        XCTAssertTrue(input.offersAccountSetup)
        XCTAssertFalse(input.hasAccount)
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .zeroCollapsed)

        AssetVisibilityPreferenceStore.setPreference(
            .shown, walletId: wallet.metaId, assetKey: bitcoin.assetKey, userDefaults: userDefaults
        )
        XCTAssertEqual(context(wallet: wallet).placement(for: bitcoin), .visible, "Show lists the setup row")
    }

    func testSolanaAccountlessOffersSetupButIsNoZeroDefault() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let solana = try XCTUnwrap(UniversalWalletRegistry.solanaMainnetChainModel.chainAssets.first {
            $0.asset.isUtility
        })

        let input = context(wallet: wallet).input(for: solana)

        XCTAssertTrue(input.offersAccountSetup)
        XCTAssertFalse(input.hasAccount)
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .zeroCollapsed)

        let vetoed = context(wallet: wallet, sendVetoedChainIds: [solana.chain.chainId])
        XCTAssertEqual(vetoed.placement(for: solana), .zeroCollapsed, "a vetoed network never invites deposits")
    }

    /// A 4.0.4 native TON wallet and an EVM-only wallet can never hold these accounts, so
    /// they are never offered a Bitcoin or Solana setup row, shown or not.
    func testNativeTonAndEvmOnlyWalletsAreNeverOfferedBitcoinOrSolanaSetup() throws {
        let base = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        let ethereumOnly = MetaAccountModel(
            metaId: base.metaId, name: base.name, substrateAccountId: nil, substrateCryptoType: 0,
            substratePublicKey: nil, ethereumAddress: base.ethereumAddress, ethereumPublicKey: base.ethereumPublicKey,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: true, unusedChainIds: nil,
            selectedCurrency: base.selectedCurrency, networkManagmentFilter: nil, assetsVisibility: [],
            hasBackup: false, favouriteChainIds: []
        )
        let bitcoin = try XCTUnwrap(UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first)
        let solana = try XCTUnwrap(UniversalWalletRegistry.solanaMainnetChainModel.chainAssets.first {
            $0.asset.isUtility
        })

        for wallet in [try LegacyNativeTonFixture.wallet(), ethereumOnly] {
            for chainAsset in [bitcoin, solana] {
                let input = context(wallet: wallet).input(for: chainAsset)
                XCTAssertFalse(input.offersAccountSetup, chainAsset.chain.name)
                XCTAssertFalse(input.hasAccount, chainAsset.chain.name)
                XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .zeroCollapsed, chainAsset.chain.name)
                XCTAssertTrue(PortfolioVisibilityContext.lacksAppOwnedAccount(chainAsset, wallet: wallet))
            }
            XCTAssertFalse(UniversalWalletStoredSeedAdopter.canAddAppOwnedAccounts(to: wallet))
        }
    }

    func testProvisionedBitcoinAtZeroIsAListedZeroDefault() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let bitcoin = try XCTUnwrap(UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first)

        let input = context(wallet: wallet).input(for: bitcoin)

        XCTAssertFalse(input.offersAccountSetup)
        XCTAssertTrue(input.isListedZeroDefault)
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(input), .visible)
    }

    func testTairaAccountlessDoesNotProduceSetupRow() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)

        XCTAssertEqual(context(wallet: wallet).placement(for: taira), .hidden)

        AssetVisibilityPreferenceStore.setPreference(
            .shown,
            walletId: wallet.metaId,
            assetKey: taira.assetKey,
            userDefaults: userDefaults
        )
        XCTAssertEqual(context(wallet: wallet).placement(for: taira), .visible, "Manage › Testnets shows it again")
    }

    func testProvisionedTairaIsHiddenUntilShown() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)
        let funded = balances(wallet: wallet, values: [taira: (free: 10, reserved: 0)])

        XCTAssertEqual(context(wallet: wallet).placement(for: taira), .hidden)
        XCTAssertEqual(context(wallet: wallet, accountInfos: funded).placement(for: taira), .hidden)
        XCTAssertEqual(
            context(wallet: wallet, accountInfos: funded, networkFilter: .chain(taira.chain.chainId)).placement(for: taira),
            .visible
        )
    }

    func testReservedOnlyBalanceCountsAsHolding() {
        let chain = makeChain(name: "Staking", rank: nil)
        let asset = makeChainAsset(chain: chain, id: "bonded", symbol: "BND")
        let wallet = AccountGenerator.generateMetaAccount()
        let reservedOnly = balances(wallet: wallet, values: [asset: (free: 0, reserved: 5)])

        XCTAssertEqual(context(wallet: wallet, accountInfos: reservedOnly).placement(for: asset), .visible)
        XCTAssertEqual(context(wallet: wallet).placement(for: asset), .zeroCollapsed)
    }

    func testLegacyHintReachesThePolicyThroughTheStore() {
        let chain = makeChain(name: "Hinted", rank: 3)
        let asset = makeChainAsset(chain: chain, id: "native", symbol: "NAT", isUtility: true, isNative: true)
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetsVisibility([
            AssetVisibility(assetId: asset.identifier, hidden: true)
        ])
        let fallbackZeroDefaults = PortfolioZeroDefaultList(entries: [])

        XCTAssertEqual(context(wallet: wallet, zeroDefaults: fallbackZeroDefaults).placement(for: asset), .visible)

        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: [asset],
            catalogIsComplete: true,
            userDefaults: userDefaults
        )

        XCTAssertEqual(context(wallet: wallet, zeroDefaults: fallbackZeroDefaults).placement(for: asset), .zeroCollapsed)
        let funded = balances(wallet: wallet, values: [asset: (free: 1, reserved: 0)])
        XCTAssertEqual(
            context(wallet: wallet, accountInfos: funded, zeroDefaults: fallbackZeroDefaults).placement(for: asset),
            .visible
        )
    }

    func testComputedFallbackWhenTheZeroListIsUnavailable() {
        let wallet = AccountGenerator.generateMetaAccount()
        let ranked = makeChainAsset(chain: makeChain(name: "Ranked", rank: 4), id: "r", symbol: "RNK", isUtility: true)
        let unranked = makeChainAsset(chain: makeChain(name: "Unranked"), id: "u", symbol: "UNR", isUtility: true)
        let rankedTestnet = makeChainAsset(
            chain: makeChain(name: "Ranked test", rank: 5, options: [.testnet]),
            id: "t",
            symbol: "TST",
            isUtility: true
        )
        let fallback = context(wallet: wallet, zeroDefaults: PortfolioZeroDefaultList(entries: []))
        let bundled = context(wallet: wallet)

        XCTAssertEqual(fallback.placement(for: ranked), .visible)
        XCTAssertEqual(fallback.placement(for: unranked), .zeroCollapsed)
        XCTAssertEqual(fallback.placement(for: rankedTestnet), .hidden)
        XCTAssertEqual(bundled.placement(for: ranked), .zeroCollapsed, "with the list loaded only listed assets are zero defaults")
    }

    func testSendVetoedChainIdsNameThePausedNetworks() throws {
        let bitcoin = UniversalWalletRegistry.bitcoinMainnet.chainId
        let solana = UniversalWalletRegistry.solanaMainnet.chainId

        XCTAssertEqual(
            PortfolioVisibilityContext.sendVetoedChainIds(bitcoinSendEnabled: true, solanaSendEnabled: true),
            []
        )
        XCTAssertEqual(
            PortfolioVisibilityContext.sendVetoedChainIds(bitcoinSendEnabled: false, solanaSendEnabled: true),
            [bitcoin]
        )
        XCTAssertEqual(
            PortfolioVisibilityContext.sendVetoedChainIds(bitcoinSendEnabled: false, solanaSendEnabled: false),
            [bitcoin, solana]
        )

        // The ids are the ones the shared zero list and the bundled network use.
        let listed = Set(PortfolioZeroDefaultList.bundled.entries.map(\.chainId))
        XCTAssertTrue(listed.isSuperset(of: [bitcoin, solana]))
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnetChainModel.chainId, bitcoin)
    }

    func testPausedBitcoinSendRemovesItsZeroRowFromThePortfolio() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let bitcoin = try XCTUnwrap(UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first)
        var bitcoinSendEnabled = true
        let factory = ChainAssetListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            sendVetoedChainIds: {
                PortfolioVisibilityContext.sendVetoedChainIds(
                    bitcoinSendEnabled: bitcoinSendEnabled,
                    solanaSendEnabled: true
                )
            }
        )
        let rows = { (accountInfos: [ChainAssetKey: AccountInfo?]) in
            factory.buildViewModel(
                wallet: wallet,
                chainAssets: [bitcoin],
                locale: Locale(identifier: "en_US"),
                accountInfos: accountInfos,
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil
            ).networkSections.flatMap(\.rows).map(\.chainAsset.assetKey)
        }

        XCTAssertEqual(rows([:]), [bitcoin.assetKey])

        // The factory reads the switch on every build.
        bitcoinSendEnabled = false
        XCTAssertEqual(rows([:]), [], "a paused network does not invite deposits")
        XCTAssertEqual(
            rows(balances(wallet: wallet, values: [bitcoin: (free: 1000, reserved: 0)])),
            [bitcoin.assetKey],
            "funds stay visible whatever the switch says"
        )
    }

    /// Critique G10: this build routes no TON send for a universal wallet (`TonProductionSendReleasePolicy`),
    /// so its TON zero row would invite deposits that cannot leave. A 4.0.4 TON wallet still sends, and
    /// keeps the row; funds always show.
    func testTonZeroRowFollowsTheTonSendPolicyOfTheWallet() throws {
        let ton = try XCTUnwrap(try registryChains().first { $0.chainId == "-239" })
        let tonAsset = try XCTUnwrap(ton.chainAssets.first { PortfolioZeroDefaultList.bundled.contains($0) })
        let universal = AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: ton.chainId,
                accountId: Data(repeating: 0x07, count: 32),
                publicKey: Data(repeating: 0x07, count: 32),
                cryptoType: CryptoType.ed25519.rawValue,
                ethereumBased: false
            )
        ])
        let legacy = try LegacyNativeTonFixture.wallet()

        let universalInput = context(wallet: universal).input(for: tonAsset)
        XCTAssertTrue(universalInput.hasAccount)
        XCTAssertTrue(universalInput.isListedZeroDefault)
        XCTAssertTrue(universalInput.isSendVetoed)
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(universalInput), .zeroCollapsed)
        XCTAssertEqual(
            context(wallet: universal, accountInfos: balances(wallet: universal, values: [tonAsset: (free: 1, reserved: 0)]))
                .placement(for: tonAsset),
            .visible,
            "funds stay visible"
        )

        let legacyInput = context(wallet: legacy).input(for: tonAsset)
        XCTAssertTrue(legacyInput.hasAccount)
        XCTAssertFalse(legacyInput.isSendVetoed, "4.0.4 TON wallets keep their send")
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(legacyInput), .visible)

        #if DEBUG
            // The row comes back by itself once TON send is enabled for every wallet.
            let enabled = PortfolioVisibilityContext(
                wallet: universal,
                accountInfos: [:],
                networkFilter: nil,
                tonSendReleasePolicy: .enabledForTests,
                userDefaults: userDefaults
            )
            XCTAssertEqual(enabled.placement(for: tonAsset), .visible)
        #endif
    }

    func testIrohaNetworksThisBuildCannotSendFromHaveNoZeroRow() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let nexus = makeChain(name: "SORA Nexus", chainId: UniversalWalletRegistry.nexus.chainId)
        let control = makeChain(name: "Control")

        XCTAssertTrue(PortfolioVisibilityContext.isSendPaused(on: nexus, wallet: wallet))
        XCTAssertTrue(PortfolioVisibilityContext.isSendPaused(on: UniversalWalletRegistry.tairaChainModel, wallet: wallet))
        XCTAssertFalse(PortfolioVisibilityContext.isSendPaused(on: control, wallet: wallet))
        XCTAssertFalse(PortfolioVisibilityContext.isSendPaused(on: UniversalWalletRegistry.bitcoinMainnetChainModel, wallet: wallet))
        let ethereum = try XCTUnwrap(try registryChains().first { $0.name == "Ethereum" })
        XCTAssertFalse(PortfolioVisibilityContext.isSendPaused(on: ethereum, wallet: wallet))

        // The primary utility asset of an only-selected network is a zero row, unless sending is paused.
        let paused = PortfolioVisibilityInput(isOnlySelectedNetwork: true, isPrimaryUtility: true, isSendVetoed: true)
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(paused), .zeroCollapsed)
        var funded = paused
        funded.balanceIsPositive = true
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(funded), .visible)
        var shown = paused
        shown.preference = .shown
        XCTAssertEqual(PortfolioVisibilityPolicy.placement(shown), .visible, "an explicit Show still lists it")
    }

    /// `ChainAssetListAssembly` reads the vetoes from the same gate Send checks, so a network the
    /// gate pauses loses its zero row and a network it allows keeps it.
    func testSendVetoesFollowTheSendGate() {
        let gate = { (bitcoin: Bool, solana: Bool) in
            UniversalSendGate(policy: .production) {
                FeatureToggleConfig(
                    pendulumCaseEnabled: nil,
                    nftEnabled: nil,
                    bitcoinSendEnabled: bitcoin,
                    solanaSendEnabled: solana
                )
            }
        }
        let bitcoinId = UniversalWalletRegistry.bitcoinMainnet.chainId
        let solanaId = UniversalWalletRegistry.solanaMainnet.chainId

        XCTAssertEqual(PortfolioVisibilityContext.sendVetoedChainIds(gate: gate(true, true)), [])
        XCTAssertEqual(PortfolioVisibilityContext.sendVetoedChainIds(gate: gate(false, true)), [bitcoinId])
        XCTAssertEqual(PortfolioVisibilityContext.sendVetoedChainIds(gate: gate(true, false)), [solanaId])
        XCTAssertEqual(PortfolioVisibilityContext.sendVetoedChainIds(gate: gate(false, false)), [bitcoinId, solanaId])
    }

    func testPrimaryUtilityPrefersListedAssetThenNativeThenLowestId() throws {
        let xLayer = try XCTUnwrap(try registryChains().first { $0.name == "X Layer Mainnet" })
        let utilitySymbols = xLayer.assets.filter(\.isUtility).map { $0.symbol.lowercased() }
        XCTAssertTrue(Set(utilitySymbols).isSuperset(of: ["okb", "wokb"]), "\(utilitySymbols)")

        let primary = try XCTUnwrap(PortfolioVisibilityPolicy.primaryUtilityAssetId(of: xLayer, zeroDefaults: .bundled))
        XCTAssertEqual(xLayer.assets.first { $0.id == primary }?.symbol.lowercased(), "okb")

        let chain = makeChain(name: "Two utilities")
        _ = makeChainAsset(chain: chain, id: "b-native", symbol: "NAT", isUtility: true, isNative: true)
        _ = makeChainAsset(chain: chain, id: "a-wrapped", symbol: "WNAT", isUtility: true)
        _ = makeChainAsset(chain: chain, id: "0-token", symbol: "TOK")
        XCTAssertEqual(PortfolioVisibilityPolicy.primaryUtilityAssetId(of: chain, zeroDefaults: .bundled), "b-native")

        let nativeOnly = makeChain(name: "Native only")
        _ = makeChainAsset(chain: nativeOnly, id: "z-native", symbol: "ZN", isNative: true)
        _ = makeChainAsset(chain: nativeOnly, id: "y-native", symbol: "YN", isNative: true)
        XCTAssertEqual(PortfolioVisibilityPolicy.primaryUtilityAssetId(of: nativeOnly, zeroDefaults: .bundled), "y-native")
    }

    /// Contract §10: the zero-default golden cases reproduced with the app's real visibility code over
    /// the reviewed registry snapshot. The shared expectation is compared unchanged.
    func testZeroDefaultParityCasesThroughThePolicy() throws {
        let data = try Data(contentsOf: XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "parity-cases.v1", withExtension: "json", subdirectory: "Registry")
        ))
        XCTAssertEqual(sha256(data), Self.parityCasesSha256)

        struct ParityCases: Decodable {
            struct ZeroDefaultCase: Decodable {
                let id: String
                let accounts: [String]
                let sendPausedChainIds: [String]?
                let expected: [String]
            }

            let zeroDefaults: [ZeroDefaultCase]
        }

        // The shared SOL row is checked on the app's own Solana network model (IOSUX-4), which
        // `registryChains()` merges in with the other app-owned networks.
        let solanaChainId = UniversalWalletRegistry.solanaMainnet.chainId
        XCTAssertTrue(try registryChains().contains { $0.chainId == solanaChainId })

        let chainAssets = try registryChains().flatMap(\.chainAssets)
        let zeroDefaults = PortfolioZeroDefaultList.bundled
        let testnets = PortfolioTestnetChainList.bundled
        let familyByEcosystem = ["substrate": "substrate", "evm": "evm", "ton": "ton", "bitcoin": "bitcoin", "solana": "solana", "iroha": "iroha"]
        var primaryIds: [ChainModel.Id: AssetModel.Id?] = [:]

        for parityCase in try JSONDecoder().decode(ParityCases.self, from: data).zeroDefaults {
            let vetoed = Set(parityCase.sendPausedChainIds ?? [])
            let visible = chainAssets.filter { chainAsset in
                let chain = chainAsset.chain
                if primaryIds[chain.chainId] == nil {
                    primaryIds[chain.chainId] = PortfolioVisibilityPolicy.primaryUtilityAssetId(
                        of: chain,
                        zeroDefaults: zeroDefaults
                    )
                }
                let family = familyByEcosystem[AssetKey.ecosystem(for: chain)]
                let input = PortfolioVisibilityInput(
                    isTestnet: testnets.isTestnet(chain),
                    hasAccount: family.map(parityCase.accounts.contains) ?? false,
                    isListedZeroDefault: zeroDefaults.contains(chainAsset),
                    isPrimaryUtility: primaryIds[chain.chainId] == chainAsset.asset.id,
                    isSendVetoed: vetoed.contains(chain.chainId)
                )
                return PortfolioVisibilityPolicy.placement(input) == .visible
            }

            let labels = Set(visible.map { "\($0.asset.symbol)@\($0.chain.name)" })
            XCTAssertEqual(labels, Set(parityCase.expected), parityCase.id)
        }
    }

    // MARK: - Helpers

    private func context(
        wallet: MetaAccountModel,
        accountInfos: [ChainAssetKey: AccountInfo?] = [:],
        networkFilter: NetworkManagmentFilter? = nil,
        zeroDefaults: PortfolioZeroDefaultList = .bundled,
        sendVetoedChainIds: Set<ChainModel.Id> = []
    ) -> PortfolioVisibilityContext {
        PortfolioVisibilityContext(
            wallet: wallet,
            accountInfos: accountInfos,
            networkFilter: networkFilter,
            zeroDefaults: zeroDefaults,
            testnets: .bundled,
            sendVetoedChainIds: sendVetoedChainIds,
            userDefaults: userDefaults
        )
    }

    private func balances(
        wallet: MetaAccountModel,
        values: [ChainAsset: (free: UInt64, reserved: UInt64)]
    ) -> [ChainAssetKey: AccountInfo?] {
        Dictionary(uniqueKeysWithValues: values.compactMap { chainAsset, value in
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return nil
            }
            return (
                chainAsset.uniqueKey(accountId: accountId),
                AccountInfo(
                    nonce: 0,
                    consumers: 0,
                    providers: 0,
                    data: AccountData(free: BigUInt(value.free), reserved: BigUInt(value.reserved), frozen: 0, flags: 0)
                )
            )
        })
    }

    private func makeChain(
        name: String,
        rank: UInt16? = nil,
        options: [ChainOptions]? = nil,
        chainId: ChainModel.Id = UUID().uuidString.lowercased()
    ) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: [],
            addressPrefix: 42,
            types: nil,
            icon: nil,
            options: options,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeChainAsset(
        chain: ChainModel,
        id: String,
        symbol: String,
        isUtility: Bool = false,
        isNative: Bool = false
    ) -> ChainAsset {
        let asset = AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: 0,
            icon: nil,
            price: nil,
            fiatDayChange: nil,
            currencyId: id,
            existentialDeposit: nil,
            color: nil,
            isUtility: isUtility,
            isNative: isNative,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
        chain.assets.insert(asset)
        return ChainAsset(chain: chain, asset: asset)
    }

    /// The reviewed registry snapshot decoded with the app's own parser, plus the networks the
    /// app merges in at runtime.
    private func registryChains() throws -> [ChainModel] {
        if let cachedRegistryChains {
            return cachedRegistryChains
        }

        let url = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: "chains_v13_20261009", withExtension: "json", subdirectory: "Registry"
        ))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(sha256(data), Self.registrySnapshotSha256)

        let chains: [ChainModel]
        do {
            chains = try JSONDecoder().decode([ChainModel].self, from: data)
        } catch {
            chains = try JSONDecoder().decode(
                [ChainModel].self,
                from: ChainSyncService.coerceChainsPayloadForCompatibility(data)
            )
        }
        let result = chains + UniversalWalletRegistry.appOwnedProductionChains
        cachedRegistryChains = result
        return result
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
