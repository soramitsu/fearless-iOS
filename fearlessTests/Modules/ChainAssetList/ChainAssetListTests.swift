import BigInt
import RobinHood
import SoraFoundation
import SSFModels
import XCTest

@testable import fearless

final class ChainAssetListTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ExactAssetPriceCache.shared.clear()
        MultiChainFeaturePolicy.update(
            FeatureToggleConfig(
                pendulumCaseEnabled: false,
                nftEnabled: true,
                assetDiscoveryShadowMode: false
            )
        )
    }

    override func tearDown() {
        ExactAssetPriceCache.shared.clear()
        MultiChainFeaturePolicy.update(.defaultConfig)
        super.tearDown()
    }

    func testStoredSeedAdoptionDeliversSuccessAfterFinishedOperationIsReleased() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let updatedWallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: wallet,
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let completionDelivered = expectation(description: "completion delivered")
        let deliveryQueue = DispatchQueue(label: "test.stored-seed-adoption.delivery")
        deliveryQueue.suspend()
        var operation: ClosureOperation<MetaAccountModel>? = ClosureOperation {
            updatedWallet
        }
        operation?.start()
        weak var weakOperation = operation

        ChainAssetListInteractor.deliverStoredSeedAdoptionResult(
            from: operation,
            deliveryQueue: deliveryQueue
        ) { result in
            XCTAssertEqual(try? result.get(), updatedWallet)
            completionDelivered.fulfill()
        }

        operation = nil
        XCTAssertNil(
            weakOperation,
            "The queued result must not rely on retaining the finished operation"
        )

        deliveryQueue.resume()
        wait(for: [completionDelivered], timeout: 1)
    }

    func testStoredSeedAdoptionDeliversFailureAfterFinishedOperationIsReleased() {
        let completionDelivered = expectation(description: "failure delivered")
        let deliveryQueue = DispatchQueue(label: "test.stored-seed-adoption.failure-delivery")
        deliveryQueue.suspend()
        var operation: ClosureOperation<MetaAccountModel>? = ClosureOperation {
            throw StoredSeedAdoptionTestError.expected
        }
        operation?.start()
        weak var weakOperation = operation

        ChainAssetListInteractor.deliverStoredSeedAdoptionResult(
            from: operation,
            deliveryQueue: deliveryQueue
        ) { result in
            switch result {
            case .success:
                XCTFail("The adopter failure must survive operation deallocation")
            case let .failure(error):
                XCTAssertEqual(error as? StoredSeedAdoptionTestError, .expected)
            }
            completionDelivered.fulfill()
        }

        operation = nil
        XCTAssertNil(weakOperation)

        deliveryQueue.resume()
        wait(for: [completionDelivered], timeout: 1)
    }

    func testProvisionedBitcoinAppearsInPortfolioAtZeroBalance() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingBitcoinMainnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let bitcoin = try XCTUnwrap(
            UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [bitcoin],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        XCTAssertEqual(viewModel.displayState.rows.map(\.chainAsset.assetKey), [bitcoin.assetKey])
        XCTAssertEqual(viewModel.displayState.rows.first?.chainAsset.asset.symbol, "BTC")
    }

    func testAccountlessBitcoinAppearsInPortfolioAsActionableSetupRow() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let bitcoin = try XCTUnwrap(
            UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [bitcoin],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        let row = try XCTUnwrap(viewModel.displayState.rows.first)
        XCTAssertEqual(row.chainAsset.assetKey, bitcoin.assetKey)
        XCTAssertEqual(row.chainAsset.asset.symbol, "BTC")
        XCTAssertFalse(row.isColdBoot, "Bitcoin setup must not be presented as an endless balance load")
        XCTAssertFalse(row.swipeActionsEnabled, "Send and receive require the BIP-84 account first")
    }

    func testBitcoinNetworkRemainsVisibleWhileWalletNeedsAccountSetup() {
        let wallet = AccountGenerator.generateMetaAccount()
        let bitcoin = UniversalWalletRegistry.bitcoinMainnetChainModel

        let viewModel = NetworkManagmentViewModelFactoryImpl().createViewModel(
            wallet: wallet,
            chains: [bitcoin],
            selectedFilter: nil,
            initialFilter: .all,
            searchText: nil,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertTrue(viewModel.cells.contains(where: {
            $0.networkSelectType.identifier == bitcoin.chainId && $0.name == "Bitcoin"
        }))
    }

    func testBitcoinOnlyFilterShowsAccountSetupInsteadOfEmptyPortfolio() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let bitcoin = try XCTUnwrap(
            UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [bitcoin],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .chain,
            chainSettings: [],
            networkFilter: .chain(bitcoin.chain.chainId),
            search: nil
        )

        guard case let .chainHasAccountIssue(chain) = viewModel.displayState else {
            return XCTFail("Bitcoin without a BIP-84 account must offer account setup")
        }
        XCTAssertEqual(chain.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
    }

    func testProvisionedTairaAppearsAtZeroBalanceWithReceiveOnlyActions() throws {
        let wallet = try UniversalWalletAccountProvisioning.addingTairaTestnetAccount(
            to: AccountGenerator.generateMetaAccount(),
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [taira],
            locale: Locale(identifier: "en_US"),
            accountInfos: balances(wallet: wallet, values: [taira: 0]),
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        let row = try XCTUnwrap(viewModel.displayState.rows.first)
        XCTAssertEqual(row.chainAsset.assetKey, taira.assetKey)
        XCTAssertEqual(row.chainAsset.asset.symbol, "XOR")
        XCTAssertFalse(row.isColdBoot)
        XCTAssertFalse(row.swipeActionsEnabled, "Taira Send must stay closed while receive remains in details")
    }

    func testAccountlessTairaIsDiscoverableAndOffersAccountSetup() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)

        let portfolio = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [taira],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        let filtered = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [taira],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .chain,
            chainSettings: [],
            networkFilter: .chain(taira.chain.chainId),
            search: nil
        )
        let networkPicker = NetworkManagmentViewModelFactoryImpl().createViewModel(
            wallet: wallet,
            chains: [taira.chain],
            selectedFilter: nil,
            initialFilter: .all,
            searchText: nil,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(portfolio.displayState.rows.map(\.chainAsset.assetKey), [taira.assetKey])
        guard case let .chainHasAccountIssue(chain) = filtered.displayState else {
            return XCTFail("Taira without an I105 account must offer account setup")
        }
        XCTAssertEqual(chain.chainId, UniversalWalletRegistry.taira.chainId)
        XCTAssertTrue(networkPicker.cells.contains(where: {
            $0.networkSelectType.identifier == UniversalWalletRegistry.taira.chainId
        }))
    }

    func testMalformedDedicatedUniversalAccountsRemainActionableSetupRows() throws {
        let malformedBitcoin = ChainAccountModel(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: Data(repeating: 0x01, count: 32),
            publicKey: Data(repeating: 0x01, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let malformedTaira = ChainAccountModel(
            chainId: UniversalWalletRegistry.taira.chainId,
            accountId: Data(repeating: 0x02, count: 32),
            publicKey: Data(repeating: 0x02, count: 32),
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(
            with: [malformedBitcoin, malformedTaira]
        )
        let bitcoin = try XCTUnwrap(
            UniversalWalletRegistry.bitcoinMainnetChainModel.chainAssets.first
        )
        let taira = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [bitcoin, taira],
            locale: Locale(identifier: "en_US"),
            accountInfos: [:],
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        XCTAssertEqual(
            Set(viewModel.displayState.rows.map(\.chainAsset.assetKey)),
            Set([bitcoin.assetKey, taira.assetKey])
        )
        XCTAssertTrue(viewModel.displayState.rows.allSatisfy { !$0.isColdBoot })
        XCTAssertTrue(viewModel.displayState.rows.allSatisfy { !$0.swipeActionsEnabled })
    }

    func testSameSymbolAssetsRemainSeparateByCanonicalIdentity() {
        let firstChain = makeChain(name: "Alpha")
        let secondChain = makeChain(name: "Beta")
        let first = makeChainAsset(chain: firstChain, id: "contract-a", symbol: "SAME")
        let second = makeChainAsset(chain: firstChain, id: "contract-b", symbol: "SAME")
        let third = makeChainAsset(chain: secondChain, id: "mint-c", symbol: "SAME")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [first: 10, second: 20, third: 30])

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [first, second, third],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        XCTAssertEqual(viewModel.networkSections.filter { $0.kind == .assets }.count, 2)
        XCTAssertEqual(Set(viewModel.displayState.rows.map(\.chainAsset.assetKey)), Set([
            first.assetKey,
            second.assetKey,
            third.assetKey
        ]))
    }

    func testManageAssetsKeepsSameSymbolBalancesAndPricesIsolatedByAssetKey() {
        let firstChain = makeChain(name: "Alpha")
        let secondChain = makeChain(name: "Beta")
        let first = makeChainAsset(
            chain: firstChain,
            id: "contract-a",
            symbol: "SAME",
            price: 2
        )
        let second = makeChainAsset(
            chain: firstChain,
            id: "contract-b",
            symbol: "SAME",
            price: 5
        )
        let third = makeChainAsset(
            chain: secondChain,
            id: "mint-c",
            symbol: "SAME"
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [first: 10, second: 20, third: 30])

        let viewModel = AssetManagementViewModelFactoryDefault(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        ).buildViewModel(
            chainAssets: [first, second, third],
            accountInfos: accountInfos,
            wallet: wallet,
            locale: Locale(identifier: "en_US"),
            filter: nil,
            search: nil,
            pendingAccountInfoChainAssets: []
        )

        XCTAssertEqual(viewModel.list.count, 3)
        XCTAssertTrue(viewModel.list.allSatisfy { !$0.hasView && $0.cells.count == 1 })
        let totals = Dictionary(uniqueKeysWithValues: viewModel.list.compactMap { section in
            section.cells.first.map { ($0.chainAsset.assetKey, section.totalFiatBalance) }
        })
        XCTAssertEqual(totals[first.assetKey], 20)
        XCTAssertEqual(totals[second.assetKey], 100)
        XCTAssertEqual(totals[third.assetKey], 0)
    }

    func testRelatedAssetResolverRequiresExplicitCuratedAssetId() {
        let destinationId = "destination-chain"
        let originId = "curated-registry-asset-id"
        let originChain = makeChain(
            name: "Origin",
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: false,
                availableAssets: [XcmAvailableAsset(id: originId, symbol: "SAME")],
                availableDestinations: [
                    XcmAvailableDestination(
                        chainId: destinationId,
                        bridgeParachainId: nil,
                        assets: [XcmAvailableAsset(id: originId, symbol: "SAME")]
                    )
                ]
            )
        )
        let destinationChain = makeChain(name: "Destination", chainId: destinationId)
        let unlistedChain = makeChain(name: "Unlisted")
        let origin = makeChainAsset(chain: originChain, id: originId, symbol: "SAME")
        let curatedDestination = makeChainAsset(
            chain: destinationChain,
            id: originId,
            symbol: "DIFFERENT DISPLAY NAME"
        )
        let sameSymbolContract = makeChainAsset(
            chain: destinationChain,
            id: "other-contract",
            symbol: "SAME"
        )
        let prefixedImposter = makeChainAsset(
            chain: destinationChain,
            id: "xc-imposter",
            symbol: "xcSAME"
        )
        let unlistedSameId = makeChainAsset(
            chain: unlistedChain,
            id: originId,
            symbol: "SAME"
        )

        let related = CuratedAssetRelationshipResolver.relatedChainAssets(
            to: origin,
            among: [
                origin,
                curatedDestination,
                sameSymbolContract,
                prefixedImposter,
                unlistedSameId
            ]
        )

        XCTAssertEqual(Set(related.map(\.assetKey)), Set([origin.assetKey, curatedDestination.assetKey]))
        XCTAssertTrue(CuratedAssetRelationshipResolver.hasCuratedXcmDestination(for: origin))
    }

    func testUnverifiedPositiveAssetMovesDetectedToShownAndHiddenPreferencesSurviveRescan() {
        let chain = makeChain(name: "Detected")
        let asset = makeChainAsset(chain: chain, id: "unknown-master", symbol: "SAME")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [asset: 25])
        let factory = makeFactory()
        AssetTrustResolver.markUnverified(asset)

        var viewModel = factory.buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertEqual(viewModel.networkSections.first { $0.kind == .detected }?.rows.map(\.chainAsset.assetKey), [asset.assetKey])

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: asset.assetKey)
        viewModel = factory.buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertNil(viewModel.networkSections.first { $0.kind == .detected })
        XCTAssertEqual(viewModel.networkSections.first { $0.kind == .assets }?.rows.map(\.chainAsset.assetKey), [asset.assetKey])

        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: asset.assetKey)
        viewModel = factory.buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(viewModel.networkSections.flatMap(\.rows).isEmpty)
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.preference(walletId: wallet.metaId, assetKey: asset.assetKey),
            .hidden
        )

        // A later scan supplies the same positive balance but does not mutate
        // the explicit presentation preference.
        let rescanned = factory.buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(rescanned.networkSections.flatMap(\.rows).isEmpty)

        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey)
    }

    func testHiddenVerifiedAssetStaysInNetworkSubtotalAndWalletNetWorth() throws {
        let pricedChain = makeChain(name: "Priced")
        let unpricedChain = makeChain(name: "Unpriced")
        let priced = makeChainAsset(chain: pricedChain, id: "priced", symbol: "USD", price: 2)
        let unpriced = makeChainAsset(chain: unpricedChain, id: "unpriced", symbol: "RAW")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [priced: 10, unpriced: 100])
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: priced.assetKey)

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [unpriced, priced],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        let assetSections = viewModel.networkSections.filter { $0.kind == .assets }
        XCTAssertEqual(assetSections.first?.chainId, pricedChain.chainId)
        XCTAssertNotNil(assetSections.first?.fiatSubtotal)
        XCTAssertTrue(assetSections.first?.rows.isEmpty == true)

        let walletBalance = try XCTUnwrap(
            WalletBalanceBuilder().buildBalance(for: accountInfos, [wallet], [priced, unpriced])?[wallet.metaId]
        )
        XCTAssertEqual(walletBalance.totalFiatValue, 20)

        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: priced.assetKey)
    }

    func testExactLivePriceUpdatePreservesCurrencyAndIgnoresLegacyScalar() throws {
        let chain = makeChain(name: "Exact price")
        let assetModel = AssetModel(
            id: "registry-row",
            name: "Exact token",
            symbol: "EXACT",
            precision: 0,
            price: 999,
            currencyId: "runtime-asset-id",
            isUtility: false,
            isNative: false,
            coingeckoPriceId: "exact-provider-id"
        )
        chain.assets.insert(assetModel)
        let chainAsset = ChainAsset(chain: chain, asset: assetModel)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [chainAsset: 10])
        let usd = Currency.defaultCurrency()
        let eur = Currency.euro()

        // A naked legacy scalar has no fiat provenance and must not be exposed.
        XCTAssertNil(chainAsset.asset.getPrice(for: usd))
        XCTAssertNil(chainAsset.asset.getPrice(for: eur))
        XCTAssertEqual(
            try XCTUnwrap(
                WalletBalanceBuilder().buildBalance(
                    for: accountInfos,
                    [wallet],
                    [chainAsset]
                )?[wallet.metaId]
            ).totalFiatValue,
            .zero
        )

        let usdPrice = PriceData(
            currencyId: usd.id,
            priceId: "exact-provider-id",
            price: "2",
            fiatDayChange: 1,
            coingeckoPriceId: "exact-provider-id"
        )
        ExactAssetPriceCache.shared.upsert([usdPrice])

        XCTAssertEqual(chainAsset.asset.getPrice(for: usd), usdPrice)
        XCTAssertNil(chainAsset.asset.getPrice(for: eur))
        XCTAssertEqual(
            try XCTUnwrap(
                WalletBalanceBuilder().buildBalance(
                    for: accountInfos,
                    [wallet],
                    [chainAsset]
                )?[wallet.metaId]
            ).totalFiatValue,
            20
        )

        let eurPrice = PriceData(
            currencyId: eur.id,
            priceId: "exact-provider-id",
            price: "3",
            fiatDayChange: 2,
            coingeckoPriceId: "exact-provider-id"
        )
        let refreshedUSD = PriceData(
            currencyId: usd.id,
            priceId: "exact-provider-id",
            price: "4",
            fiatDayChange: 3,
            coingeckoPriceId: "exact-provider-id"
        )
        ExactAssetPriceCache.shared.upsert([eurPrice, refreshedUSD])

        XCTAssertEqual(chainAsset.asset.getPrice(for: usd), refreshedUSD)
        XCTAssertEqual(chainAsset.asset.getPrice(for: eur), eurPrice)

        ExactAssetPriceCache.shared.replaceAll(with: [eurPrice])
        XCTAssertNil(chainAsset.asset.getPrice(for: usd))
        XCTAssertEqual(chainAsset.asset.getPrice(for: eur), eurPrice)
        ExactAssetPriceCache.shared.clear()
        XCTAssertNil(chainAsset.asset.getPrice(for: eur))
    }

    func testCanonicalVisibilityEventInvalidatesOnlyMatchingWalletPortfolio() {
        let wallet = AccountGenerator.generateMetaAccount()
        let otherWallet = AccountGenerator.generateMetaAccount()
        let chainAsset = makeChainAsset(
            chain: makeChain(name: "Visibility"),
            id: "canonical-asset",
            symbol: "CAN"
        )
        let output = ChainAssetListInteractorOutputSpy()
        let event = AssetVisibilityPreferenceChangedEvent(
            walletId: wallet.metaId,
            assetKey: chainAsset.assetKey,
            preference: .hidden
        )

        AssetVisibilityPreferenceStore.setPreference(
            .hidden,
            walletId: wallet.metaId,
            assetKey: chainAsset.assetKey
        )
        defer {
            AssetVisibilityPreferenceStore.setPreference(
                .auto,
                walletId: wallet.metaId,
                assetKey: chainAsset.assetKey
            )
        }

        ChainAssetListInteractor.invalidateViewModel(
            for: event,
            walletId: otherWallet.metaId,
            output: output
        )
        XCTAssertEqual(output.updateViewModelCalls, 0)

        ChainAssetListInteractor.invalidateViewModel(
            for: event,
            walletId: wallet.metaId,
            output: output
        )
        XCTAssertEqual(output.updateViewModelCalls, 1)
        XCTAssertEqual(output.lastIsInitSearchState, false)

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [chainAsset],
            locale: Locale(identifier: "en_US"),
            accountInfos: balances(wallet: wallet, values: [chainAsset: 10]),
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(viewModel.networkSections.flatMap(\.rows).isEmpty)
    }

    func testZeroBalancePricedNativeDoesNotPromoteUnpricedFundedNetwork() {
        let pricedChain = makeChain(name: "Zulu", rank: 1)
        let unpricedChain = makeChain(name: "Alpha")
        let pricedZero = makeChainAsset(
            chain: pricedChain,
            id: "native",
            symbol: "NATIVE",
            price: 1,
            isUtility: true,
            isNative: true
        )
        let unpricedOnPricedChain = makeChainAsset(
            chain: pricedChain,
            id: "raw-zulu",
            symbol: "RAWZ"
        )
        let unpricedPositive = makeChainAsset(chain: unpricedChain, id: "raw", symbol: "RAW")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(
            wallet: wallet,
            values: [pricedZero: 0, unpricedOnPricedChain: 7, unpricedPositive: 5]
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [unpricedPositive, pricedZero, unpricedOnPricedChain],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        let assetSections = viewModel.networkSections.filter { $0.kind == .assets }
        XCTAssertEqual(assetSections.map(\.chainId), [unpricedChain.chainId, pricedChain.chainId])
        XCTAssertTrue(assetSections.allSatisfy { $0.fiatSubtotal == nil })
    }

    func testLegacyGroupHideOnlyCreatesTombstonesForAssetsKnownAtMigration() throws {
        let suiteName = "ChainAssetListTests.legacy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeChainAsset(chain: makeChain(name: "First"), id: "one", symbol: "SAME")
        let second = makeChainAsset(chain: makeChain(name: "Second"), id: "two", symbol: "SAME")
        let later = makeChainAsset(chain: makeChain(name: "Later"), id: "three", symbol: "SAME")
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetsVisibility([
            AssetVisibility(assetId: "SAME", hidden: true)
        ])

        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: [first, second],
            catalogIsComplete: true,
            userDefaults: defaults
        )

        XCTAssertEqual(preference(first, wallet: wallet, defaults: defaults), .hidden)
        XCTAssertEqual(preference(second, wallet: wallet, defaults: defaults), .hidden)
        XCTAssertEqual(preference(later, wallet: wallet, defaults: defaults), .auto)
    }

    func testIncompleteLegacyMigrationDoesNotCommitAndRetriesWithDisabledNetworkAssets() throws {
        let suiteName = "ChainAssetListTests.legacy-retry.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let enabled = makeChainAsset(chain: makeChain(name: "Enabled"), id: "one", symbol: "SAME")
        let disabled = makeChainAsset(
            chain: makeChain(name: "Disabled", disabled: true),
            id: "two",
            symbol: "SAME"
        )
        let wallet = AccountGenerator.generateMetaAccount().replacingAssetsVisibility([
            AssetVisibility(assetId: "SAME", hidden: true)
        ])

        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: [enabled],
            catalogIsComplete: false,
            userDefaults: defaults
        )
        XCTAssertEqual(preference(enabled, wallet: wallet, defaults: defaults), .auto)

        AssetVisibilityPreferenceStore.migrateLegacyHides(
            wallet: wallet,
            chainAssets: [enabled, disabled],
            catalogIsComplete: true,
            userDefaults: defaults
        )
        XCTAssertEqual(preference(enabled, wallet: wallet, defaults: defaults), .hidden)
        XCTAssertEqual(preference(disabled, wallet: wallet, defaults: defaults), .hidden)
    }

    func testEvmAssetKeyNormalizesCaseButOtherEcosystemsPreserveAssetIdCase() {
        XCTAssertEqual(
            AssetKey(ecosystem: "EVM", chainId: "0xABC", assetId: "0xAbCd"),
            AssetKey(ecosystem: "evm", chainId: "0xabc", assetId: "0xabcd")
        )
        XCTAssertNotEqual(
            AssetKey(ecosystem: "solana", chainId: "SOLANA:MAINNET", assetId: "MintABC"),
            AssetKey(ecosystem: "solana", chainId: "solana:mainnet", assetId: "mintabc")
        )
    }

    func testChainAssetKeyUsesRuntimeCurrencyIdentityBeforeRegistryRowId() {
        let chain = makeChain(name: "Runtime asset network")
        let runtimeAsset = AssetModel(
            id: "registry-row-17",
            name: "Runtime asset",
            symbol: "RTA",
            precision: 12,
            currencyId: "runtime-currency-id-42",
            isUtility: false,
            isNative: false,
            type: .assets
        )
        let registryOnlyAsset = AssetModel(
            id: "canonical-mint-or-master",
            name: "Dynamic asset",
            symbol: "DYN",
            precision: 9,
            isUtility: false,
            isNative: false
        )

        XCTAssertEqual(runtimeAsset.canonicalAssetId, "runtime-currency-id-42")
        XCTAssertEqual(
            ChainAsset(chain: chain, asset: runtimeAsset).assetKey.assetId,
            "runtime-currency-id-42"
        )
        XCTAssertEqual(registryOnlyAsset.canonicalAssetId, "canonical-mint-or-master")
        XCTAssertEqual(
            ChainAsset(chain: chain, asset: registryOnlyAsset).assetKey.assetId,
            "canonical-mint-or-master"
        )
    }

    func testIrohaFallbackPrecisionDoesNotShrinkAcrossRescans() throws {
        let suiteName = "ChainAssetListTests.iroha.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = AssetKey(ecosystem: "iroha", chainId: "iroha:test", assetId: "xor#wonderland")

        DynamicAssetPrecisionStore.remember(18, for: key, userDefaults: defaults)

        XCTAssertEqual(DynamicAssetPrecisionStore.precision(for: key, userDefaults: defaults), 18)
        XCTAssertGreaterThanOrEqual(
            DynamicAssetPrecisionStore.precision(for: key, userDefaults: defaults) ?? 0,
            2
        )
    }

    func testFailureScanStateKeepsLastSuccessAndMarksError() throws {
        let suiteName = "ChainAssetListTests.scan.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let chain = makeChain(name: "Network")
        let walletId = UUID().uuidString

        NetworkScanStateStore.markSuccess(for: chain, walletId: walletId, userDefaults: defaults)
        let successful = NetworkScanStateStore.state(for: chain, walletId: walletId, userDefaults: defaults)
        NetworkScanStateStore.markFailure(for: chain, walletId: walletId, userDefaults: defaults)
        let failed = NetworkScanStateStore.state(for: chain, walletId: walletId, userDefaults: defaults)

        XCTAssertNotNil(successful.lastSuccess)
        XCTAssertEqual(failed.lastSuccess, successful.lastSuccess)
        XCTAssertTrue(failed.hasError)
    }

    func testAttemptAndFailurePreserveLastSuccessfulDynamicCoverage() throws {
        let suiteName = "ChainAssetListTests.scan.coverage.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let chain = makeChain(name: "Bitcoin", chainId: "bitcoin:mainnet")
        let walletId = UUID().uuidString

        NetworkScanStateStore.markSuccess(
            for: chain,
            coverage: .complete,
            walletId: walletId,
            userDefaults: defaults
        )
        NetworkScanStateStore.markAttempt(for: chain, walletId: walletId, userDefaults: defaults)
        let attempted = NetworkScanStateStore.state(
            for: chain,
            walletId: walletId,
            userDefaults: defaults
        )
        NetworkScanStateStore.markFailure(for: chain, walletId: walletId, userDefaults: defaults)
        let failed = NetworkScanStateStore.state(
            for: chain,
            walletId: walletId,
            userDefaults: defaults
        )

        XCTAssertEqual(attempted.coverage, .complete)
        XCTAssertEqual(failed.coverage, .complete)
        XCTAssertTrue(failed.hasError)

        NetworkScanStateStore.markSuccess(
            for: chain,
            coverage: .limited,
            walletId: walletId,
            userDefaults: defaults
        )
        XCTAssertEqual(
            NetworkScanStateStore.state(
                for: chain,
                walletId: walletId,
                userDefaults: defaults
            ).coverage,
            .limited
        )
    }

    func testNetworkScanStatusIncludesDeterministicFreshnessAndRetainsItOnFailure() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let recent = NetworkScanState(
            lastAttempt: now,
            lastSuccess: now.addingTimeInterval(-30),
            hasError: false,
            coverage: .complete
        )
        XCTAssertEqual(recent.displayText(now: now), "Full discovery · Synced just now")

        let twelveMinutesAgo = now.addingTimeInterval(-12 * 60)
        let failed = NetworkScanState(
            lastAttempt: now,
            lastSuccess: twelveMinutesAgo,
            hasError: true,
            coverage: .catalogOnly
        )
        XCTAssertEqual(
            failed.displayText(now: now),
            "Sync error · Catalog only · Synced 12m ago"
        )

        let stale = NetworkScanState(
            lastAttempt: now,
            lastSuccess: now.addingTimeInterval(-2 * 24 * 60 * 60),
            hasError: false,
            coverage: .limited
        )
        XCTAssertEqual(
            stale.displayText(now: now),
            "Stale · Limited discovery · Synced 2d ago"
        )
    }

    func testDiscoveryShadowModeSuppressesAutoDetectedPresentationButKeepsExplicitShow() {
        let chain = makeChain(name: "Shadow")
        let asset = makeChainAsset(chain: chain, id: "unverified", symbol: "NEW")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [asset: 10])
        AssetTrustResolver.markUnverified(asset)
        MultiChainFeaturePolicy.update(
            FeatureToggleConfig(
                pendulumCaseEnabled: false,
                nftEnabled: true,
                assetDiscoveryShadowMode: true
            )
        )

        var viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(viewModel.networkSections.flatMap(\.rows).isEmpty)

        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: asset.assetKey)
        viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertEqual(viewModel.networkSections.flatMap(\.rows).map(\.chainAsset.assetKey), [asset.assetKey])
        AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey)
    }

    func testExplicitlyShownNonNativeAssetAtZeroRemainsPreferenceButLeavesPortfolio() {
        let chain = makeChain(name: "Zero balance")
        let asset = makeChainAsset(chain: chain, id: "zero-token", symbol: "ZERO")
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, values: [asset: 0])
        AssetVisibilityPreferenceStore.setPreference(
            .shown,
            walletId: wallet.metaId,
            assetKey: asset.assetKey
        )

        let viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )

        XCTAssertTrue(viewModel.networkSections.flatMap(\.rows).isEmpty)
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.preference(
                walletId: wallet.metaId,
                assetKey: asset.assetKey
            ),
            .shown
        )
    }

    func testZeroNativeAssetOnFavoritedUnrankedNetworkRemainsVisibleUnlessHidden() {
        let chain = makeChain(name: "Pinned unranked", rank: nil)
        let asset = makeChainAsset(
            chain: chain,
            id: "native",
            symbol: "PIN",
            isUtility: true,
            isNative: true
        )
        let wallet = AccountGenerator.generateMetaAccount().replacingFavoutites([chain.chainId])
        let accountInfos = balances(wallet: wallet, values: [asset: 0])

        var viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertEqual(viewModel.networkSections.flatMap(\.rows).map(\.chainAsset.assetKey), [asset.assetKey])

        AssetVisibilityPreferenceStore.setPreference(
            .hidden,
            walletId: wallet.metaId,
            assetKey: asset.assetKey
        )
        viewModel = makeFactory().buildViewModel(
            wallet: wallet,
            chainAssets: [asset],
            locale: Locale(identifier: "en_US"),
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .assetChains,
            chainSettings: [],
            networkFilter: nil,
            search: nil
        )
        XCTAssertTrue(viewModel.networkSections.flatMap(\.rows).isEmpty)
        AssetVisibilityPreferenceStore.setPreference(
            .auto,
            walletId: wallet.metaId,
            assetKey: asset.assetKey
        )
    }

    func testDailyDiscoveryIsDueBoundedProductionOnlyAndRotatesCursor() throws {
        let suiteName = "ChainAssetListTests.daily.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = DailyAssetDiscoveryScheduler(
            userDefaults: defaults,
            interval: 3600,
            maximumNetworks: 2
        )
        let wallet = AccountGenerator.generateMetaAccount()
        let production = [
            makeChain(name: "One", chainId: "01"),
            makeChain(name: "Two", chainId: "02"),
            makeChain(name: "Three", chainId: "03")
        ]
        let testnet = makeChain(name: "Test", chainId: "00", options: [.testnet])
        let now = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertTrue(scheduler.isDue(walletId: wallet.metaId, now: now))
        XCTAssertEqual(
            scheduler.eligibleChains(from: production + [testnet], wallet: wallet).map(\.chainId),
            ["01", "02"]
        )
        XCTAssertEqual(
            scheduler.eligibleChains(from: production + [testnet], wallet: wallet).map(\.chainId),
            ["03", "01"]
        )

        scheduler.markAttempt(walletId: wallet.metaId, now: now)
        XCTAssertFalse(scheduler.isDue(walletId: wallet.metaId, now: now.addingTimeInterval(3599)))
        XCTAssertTrue(scheduler.isDue(walletId: wallet.metaId, now: now.addingTimeInterval(3600)))
        XCTAssertFalse(
            scheduler.eligibleChains(from: [testnet], wallet: wallet).contains(where: \.isTestnet)
        )
        XCTAssertTrue(
            scheduler.eligibleChains(
                from: [testnet],
                wallet: wallet,
                includeTestnets: true
            ).contains(where: \.isTestnet)
        )
    }

    func testCompleteDiscoveryCatalogIncludesDisabledProductionNetworksWithoutActivatingThem() {
        let wallet = AccountGenerator.generateMetaAccount()
        let enabled = makeChain(name: "Enabled", chainId: "enabled")
        let disabled = makeChain(name: "Disabled", disabled: true, chainId: "disabled")
        let testnet = makeChain(
            name: "Testnet",
            chainId: "testnet",
            options: [.testnet]
        )
        let catalog = AssetDiscoveryChainCatalog(
            chains: [enabled, disabled, testnet],
            isComplete: true
        )

        XCTAssertEqual(
            Set(catalog.productionChains(wallet: wallet).map(\.chainId)),
            Set([enabled.chainId, disabled.chainId])
        )
        XCTAssertTrue(disabled.disabled)
        XCTAssertEqual(
            Set(
                catalog.productionChains(
                    wallet: wallet,
                    optedInTestnetIds: [testnet.chainId]
                ).map(\.chainId)
            ),
            Set([enabled.chainId, disabled.chainId, testnet.chainId])
        )
    }

    func testAssetDiscoveryScansRequestedNetworksIndependentlyOfPresentationPreferences() async throws {
        let suiteName = "ChainAssetListTests.discovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let wallet = AccountGenerator.generateMetaAccount()
        let firstChain = makeChain(name: "Alpha", chainId: "discovery-alpha")
        let secondChain = makeChain(name: "Beta", chainId: "discovery-beta")
        let firstAsset = makeChainAsset(chain: firstChain, id: "hidden-a", symbol: "A")
        _ = makeChainAsset(chain: secondChain, id: "visible-b", symbol: "B")
        AssetVisibilityPreferenceStore.setPreference(
            .hidden,
            walletId: wallet.metaId,
            assetKey: firstAsset.assetKey,
            userDefaults: defaults
        )

        let remote = DiscoveryAccountInfoRemoteStub()
        let service: AssetDiscoveryService = AssetDiscoveryServiceAdapter(
            accountInfoRemote: remote,
            userDefaults: defaults
        )
        let result = await service.scan(
            wallet: wallet,
            chains: [firstChain, secondChain],
            includeTestnets: false,
            trigger: .pullToRefresh
        )

        XCTAssertEqual(result.trigger, .pullToRefresh)
        XCTAssertEqual(remote.recordedChainIds(), Set([firstChain.chainId, secondChain.chainId]))
        XCTAssertEqual(
            Set(result.accountInfosByChain.keys.map(\.chainId)),
            Set([firstChain.chainId, secondChain.chainId])
        )
        XCTAssertTrue(result.failedChainIds.isEmpty)
        XCTAssertEqual(
            AssetVisibilityPreferenceStore.preference(
                walletId: wallet.metaId,
                assetKey: firstAsset.assetKey,
                userDefaults: defaults
            ),
            .hidden
        )
    }

    func testRemoteLastKnownBalancesPersistByAssetKeyAndAuthoritativeZeroOverwritesValue() throws {
        let suiteName = "ChainAssetListTests.last-known.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let chain = makeChain(name: "Remote", chainId: "solana:mainnet")
        let first = makeChainAsset(chain: chain, id: "mint-a", symbol: "SAME")
        let second = makeChainAsset(chain: chain, id: "mint-b", symbol: "SAME")
        let wallet = AccountGenerator.generateMetaAccount()

        RemoteLastKnownBalanceStore.save(
            [first.chainAssetId: Optional(AccountInfo(ethBalance: BigUInt(99)))],
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        var loaded = RemoteLastKnownBalanceStore.load(
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        XCTAssertEqual((loaded[first.chainAssetId] ?? nil)?.data.sendAvailable, BigUInt(99))
        XCTAssertNil(loaded[second.chainAssetId] ?? nil)

        RemoteLastKnownBalanceStore.save(
            [first.chainAssetId: Optional(AccountInfo(ethBalance: .zero))],
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        loaded = RemoteLastKnownBalanceStore.load(
            chain: chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        XCTAssertEqual((loaded[first.chainAssetId] ?? nil)?.data.sendAvailable, .zero)
    }

    func testFailedDiscoveryReturnsPersistedBalanceAndMarksNetworkStale() async {
        let wallet = AccountGenerator.generateMetaAccount()
        // Use a network for which the generated test wallet has an account.
        // Ecosystem-specific wallets are intentionally filtered before a
        // remote request when the required account is absent.
        let chain = makeChain(
            name: "Remote",
            chainId: "failed-substrate-\(UUID().uuidString.lowercased())"
        )
        let asset = makeChainAsset(chain: chain, id: "mint-a", symbol: "TOKEN")
        let retained: [ChainAssetId: AccountInfo?] = [
            asset.chainAssetId: Optional(AccountInfo(ethBalance: BigUInt(77)))
        ]
        let remote = FailingLastKnownRemoteStub(retained: retained)
        let result = await AssetDiscoveryServiceAdapter(accountInfoRemote: remote).scan(
            wallet: wallet,
            chains: [chain],
            includeTestnets: false,
            trigger: .pullToRefresh
        )

        XCTAssertEqual(result.failedChainIds, Set([chain.chainId]))
        XCTAssertEqual(
            (result.accountInfosByChain[chain]?[asset.chainAssetId] ?? nil)?.data.sendAvailable,
            BigUInt(77)
        )
        XCTAssertTrue(NetworkScanStateStore.state(for: chain, walletId: wallet.metaId).hasError)
    }

    private func makeFactory() -> ChainAssetListViewModelFactory {
        ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
    }

    private func makeChain(
        name: String,
        rank: UInt16? = nil,
        disabled: Bool = false,
        chainId: String = UUID().uuidString.lowercased(),
        xcm: XcmChain? = nil,
        options: [ChainOptions]? = nil
    ) -> ChainModel {
        ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: xcm,
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
        price: Decimal? = nil,
        isUtility: Bool = false,
        isNative: Bool = false
    ) -> ChainAsset {
        let asset = AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: 0,
            icon: nil,
            price: price,
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
            coingeckoPriceId: price == nil ? nil : id
        )
        chain.assets.insert(asset)

        if let price,
           let priceId = asset.priceId {
            ExactAssetPriceCache.shared.upsert([
                PriceData(
                    currencyId: Currency.defaultCurrency().id,
                    priceId: priceId,
                    price: NSDecimalNumber(decimal: price).stringValue,
                    fiatDayChange: nil,
                    coingeckoPriceId: asset.coingeckoPriceId
                )
            ])
        }

        return ChainAsset(chain: chain, asset: asset)
    }

    private func balances(
        wallet: MetaAccountModel,
        values: [ChainAsset: UInt64]
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
                    data: AccountData(free: BigUInt(value), reserved: 0, frozen: 0, flags: 0)
                )
            )
        })
    }

    private func preference(
        _ chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        defaults: UserDefaults
    ) -> AssetPreference {
        AssetVisibilityPreferenceStore.preference(
            walletId: wallet.metaId,
            assetKey: chainAsset.assetKey,
            userDefaults: defaults
        )
    }
}

private final class FailingLastKnownRemoteStub: AccountInfoRemoteService,
    AccountInfoLastKnownBalanceProviding,
    @unchecked Sendable {
    let retained: [ChainAssetId: AccountInfo?]

    init(retained: [ChainAssetId: AccountInfo?]) {
        self.retained = retained
    }

    func fetchAccountInfos(
        for _: ChainModel,
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        throw ConvenienceError(error: "offline")
    }

    func fetchAccountInfo(
        for _: ChainAsset,
        wallet _: MetaAccountModel
    ) async throws -> AccountInfo? {
        throw ConvenienceError(error: "offline")
    }

    func lastKnownAccountInfos(
        for _: ChainModel,
        wallet _: MetaAccountModel
    ) -> [ChainAssetId: AccountInfo?] {
        retained
    }
}

private final class DiscoveryAccountInfoRemoteStub: AccountInfoRemoteService, @unchecked Sendable {
    private let lock = NSLock()
    private var chainIds = Set<ChainModel.Id>()

    func fetchAccountInfos(
        for chain: ChainModel,
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        lock.withLock {
            _ = chainIds.insert(chain.chainId)
        }
        return [:]
    }

    func fetchAccountInfo(
        for _: ChainAsset,
        wallet _: MetaAccountModel
    ) async throws -> AccountInfo? {
        nil
    }

    func recordedChainIds() -> Set<ChainModel.Id> {
        lock.withLock { chainIds }
    }
}

private final class ChainAssetListInteractorOutputSpy: ChainAssetListInteractorOutput {
    private(set) var updateViewModelCalls = 0
    private(set) var lastIsInitSearchState: Bool?

    func updateViewModel(isInitSearchState: Bool) {
        updateViewModelCalls += 1
        lastIsInitSearchState = isInitSearchState
    }

    func didReceiveChainAssets(result _: Result<[ChainAsset], Error>) {}
    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for _: ChainAsset) {}
    func didReceiveWallet(wallet _: MetaAccountModel) {}
    func didReceiveChainsWithIssues(_: [ChainIssue]) {}
    func didReceive(accountInfosByChainAssets _: [ChainAsset: AccountInfo?]) {}
    func handleWalletChanged(wallet _: MetaAccountModel) {}
    func didReceive(chainSettings _: [ChainSettings]) {}
    func didAdoptStoredWalletSeed(result _: Result<MetaAccountModel, Error>) {}
}

private enum StoredSeedAdoptionTestError: Error, Equatable {
    case expected
}
