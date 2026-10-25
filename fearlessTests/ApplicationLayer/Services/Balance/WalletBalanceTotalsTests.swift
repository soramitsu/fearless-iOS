import BigInt
import XCTest
@testable import fearless
import SSFModels

/// IOSUX-7: one value definition (root `docs/portfolio-contract.md` §3, critique C4/C5). Rows,
/// network subtotals and the header count the total balance (free + reserved) times each asset's
/// own trusted price over the same set: hidden, testnet, unverified and unpriced holdings stay out
/// and are labelled; the header is wallet-wide under a network filter; wallet management counts
/// hidden funds ("incl. hidden"). Upgrade cases start from the rows App Store 4.0.4 wrote
/// (`LegacyVisibility/`, produced by re-implementing the shipped writers).
final class WalletBalanceTotalsTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var standardPreferences: [(MetaAccountId, AssetKey)] = []

    override func setUp() {
        super.setUp()
        suiteName = "WalletBalanceTotalsTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        for (walletId, assetKey) in standardPreferences {
            AssetVisibilityPreferenceStore.setPreference(.auto, walletId: walletId, assetKey: assetKey)
        }
        standardPreferences = []
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    // MARK: - Header

    func testHeaderTotalExcludesExplicitHidden() throws {
        let chain = makeChain(name: "Alpha")
        let visible = makeChainAsset(chain: chain, symbol: "VIS", price: 2)
        let hidden = makeChainAsset(chain: chain, symbol: "HID", price: 5)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, [visible: (10, 0, 0), hidden: (4, 0, 0)])
        hide(hidden, in: wallet)

        let balance = try header(wallet, [visible, hidden], accountInfos)

        XCTAssertEqual(balance.enabledAssetFiatBalance, 20)
        XCTAssertEqual(balance.totalFiatValue, 40, "wallet management still counts the hidden holding")
        XCTAssertEqual(balance.exclusions.hiddenCount, 1)
        XCTAssertEqual(balance.exclusions.hiddenFiat, 20)
        XCTAssertEqual(balance.allHoldingsCaption, PortfolioTestCopy.text("portfolio.balance.incl_hidden"))
    }

    func testHeaderTotalIncludesStakedReservedBalance() throws {
        let chain = makeChain(name: "Staking")
        let native = makeChainAsset(chain: chain, symbol: "STK", price: 3, isUtility: true, isNative: true)
        let wallet = AccountGenerator.generateMetaAccount()
        // 1,000 in all: 900 reserved by staking, and 90 of the free 100 frozen by a lock.
        let accountInfos = balances(wallet: wallet, [native: (100, 900, 90)])

        let balance = try header(wallet, [native], accountInfos)
        let viewModel = buildList(wallet, [native], accountInfos)

        XCTAssertEqual(balance.enabledAssetFiatBalance, 3000)
        let row = try XCTUnwrap(viewModel.networkSections.flatMap(\.rows).first)
        XCTAssertEqual(row.balanceString, .normal("1000.000"))
        XCTAssertEqual(row.transferableString, PortfolioTestCopy.text("portfolio.asset.transferable", "10.000"))
        XCTAssertEqual(row.totalAmountString, .normal("$3,000"))
        XCTAssertEqual(viewModel.networkSections.first?.fiatSubtotal, "$3,000")
        XCTAssertNil(balance.allHoldingsCaption)
    }

    func testRowWithoutLocksHasNoTransferableLine() throws {
        let chain = makeChain(name: "Plain")
        let asset = makeChainAsset(chain: chain, symbol: "PLN", price: 1)
        let wallet = AccountGenerator.generateMetaAccount()

        let row = try XCTUnwrap(
            buildList(wallet, [asset], balances(wallet: wallet, [asset: (7, 0, 0)]))
                .networkSections.flatMap(\.rows).first
        )

        XCTAssertEqual(row.balanceString, .normal("7.000"))
        XCTAssertNil(row.transferableString)
    }

    /// Audit IOS-G-06: a holding locked in full (dApp staking on an unranked network) keeps its row,
    /// its value and its section, as App Store 4.0.4 showed it.
    func testFullyLockedHoldingKeepsItsRowAndValue() throws {
        let chain = makeChain(name: "Unranked")
        let native = makeChainAsset(chain: chain, symbol: "LCK", price: 2, isUtility: true, isNative: true)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, [native: (50, 0, 50)])

        let viewModel = buildList(wallet, [native], accountInfos)

        let section = try XCTUnwrap(viewModel.networkSections.first { $0.chainId == chain.chainId })
        let row = try XCTUnwrap(section.rows.first)
        XCTAssertEqual(row.balanceString, .normal("50.000"))
        XCTAssertEqual(row.transferableString, PortfolioTestCopy.text("portfolio.asset.transferable", "0"))
        XCTAssertEqual(row.totalAmountString, .normal("$100"))
        XCTAssertEqual(section.fiatSubtotal, "$100")
        XCTAssertEqual(try header(wallet, [native], accountInfos).enabledAssetFiatBalance, 100)
    }

    func testHeaderTotalExcludesUnverifiedAndUnpriced() throws {
        let chain = makeChain(name: "Mixed")
        let priced = makeChainAsset(chain: chain, symbol: "PRC", price: 1)
        let unpriced = makeChainAsset(chain: chain, symbol: "RAW")
        let detected = makeChainAsset(chain: chain, symbol: "DET", price: 100)
        AssetTrustResolver.markUnverified(detected)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, [priced: (5, 0, 0), unpriced: (9, 0, 0), detected: (9, 0, 0)])

        let balance = try header(wallet, [priced, unpriced, detected], accountInfos)
        let viewModel = buildList(wallet, [priced, unpriced, detected], accountInfos)

        XCTAssertEqual(balance.enabledAssetFiatBalance, 5)
        XCTAssertEqual(balance.totalFiatValue, 5)
        XCTAssertEqual(balance.exclusions.unpricedCount, 1, "detected tokens are not reported as unpriced")
        XCTAssertEqual(viewModel.networkSections.first { $0.kind == .assets }?.fiatSubtotal, "$5")
        let unpricedRow = try XCTUnwrap(viewModel.networkSections.flatMap(\.rows).first { $0.chainAsset == unpriced })
        XCTAssertEqual(unpricedRow.totalAmountString, .normal(nil))
        XCTAssertEqual(attributedText(unpricedRow.priceAttributedString), PortfolioTestCopy.text("portfolio.asset.price_unavailable"))
        XCTAssertEqual(
            viewModel.exclusions,
            [PortfolioExclusionCaption(kind: .unpricedAssets, text: PortfolioTestCopy.text("portfolio.exclusions.unpriced.one", 1))]
        )
    }

    /// Critique G2: a priced testnet token (Canary Matrixchain cENJ is priced as ENJ) is never
    /// counted, by the registry option or by the shared testnet list.
    func testHeaderTotalExcludesTestnetHoldingsEvenWhenPriced() throws {
        let optionTestnet = makeChain(name: "Canary", options: [.testnet])
        let listedTestnet = makeChain(name: "Ankara")
        let mainnet = makeChain(name: "Mainnet")
        let cenj = makeChainAsset(chain: optionTestnet, symbol: "CENJ", price: 4)
        let caga = makeChainAsset(chain: listedTestnet, symbol: "CAGA", price: 4)
        let main = makeChainAsset(chain: mainnet, symbol: "MAIN", price: 1)
        let testnets = PortfolioTestnetChainList(chainIds: [listedTestnet.chainId])
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, [cenj: (10, 0, 0), caga: (10, 0, 0), main: (3, 0, 0)])
        hide(caga, in: wallet)

        let balance = try XCTUnwrap(
            WalletBalanceBuilder(testnets: testnets)
                .buildBalance(for: accountInfos, [wallet], [cenj, caga, main])?[wallet.metaId]
        )

        XCTAssertEqual(balance.enabledAssetFiatBalance, 3)
        XCTAssertEqual(balance.totalFiatValue, 3, "a hidden testnet token has no value either")
        XCTAssertEqual(balance.exclusions, PortfolioExclusions(testnetCount: 2), "labelled as testnet, not as hidden")
        XCTAssertNil(balance.allHoldingsCaption)
        XCTAssertEqual(
            ChainAssetListViewModelFactory.exclusionCaptions(for: balance.exclusions),
            [PortfolioExclusionCaption(kind: .testnetAssets, text: PortfolioTestCopy.text("portfolio.exclusions.testnet.other", 2))]
        )

        // Picked as the only network, the testnet row is listed but says it has no value.
        let selected = ChainAssetListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            testnets: testnets
        ).buildViewModel(
            wallet: wallet,
            chainAssets: [cenj, caga, main],
            locale: locale,
            accountInfos: accountInfos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: .chain,
            chainSettings: [],
            networkFilter: .chain(optionTestnet.chainId),
            search: nil
        )
        let row = try XCTUnwrap(selected.displayState.rows.first)
        XCTAssertEqual(row.chainAsset, cenj)
        XCTAssertEqual(row.totalAmountString, .normal(nil))
        XCTAssertEqual(attributedText(row.priceAttributedString), PortfolioTestCopy.text("portfolio.asset.testnet_no_value"))
        XCTAssertNil(selected.networkSections.first?.fiatSubtotal)
    }

    /// Critique T-11 on the reviewed registry: Canary Matrixchain's cENJ is priced (as ENJ), and CAGA
    /// Ankara and Avail Turing lack the registry's testnet option. Funded in an upgraded 4.0.4
    /// wallet, none of them adds to the header, a subtotal or the wallet-management total; they
    /// are labelled as testnet assets, not as assets without a price.
    func testRegistryTestnetsAreNeverCountedAfterA404Upgrade() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-regular-scanned", userDefaults: userDefaults)
        let testnetAssets = try [
            ("Canary Matrixchain", "cenj"),
            ("CAGA Ankara Testnet", "caga"),
            ("Avail Turing Testnet", "avail")
        ].map { network, symbol in
            try XCTUnwrap(scenario.asset(byNetwork: network, symbol: symbol), network)
        }
        XCTAssertNotNil(testnetAssets[0].asset.priceId, "cENJ is priced in the registry")
        try upsertPrices(for: scenario.catalog.filter(scenario.isFunded) + [testnetAssets[0]])
        scenario.migrate()

        let before = Self.lookedUp(scenario)
        var after = before
        for chainAsset in testnetAssets {
            let accountId = try XCTUnwrap(scenario.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId)
            let planks = BigUInt(10).power(Int(chainAsset.asset.precision)) * 50
            after[chainAsset.uniqueKey(accountId: accountId)] = AccountInfo(
                nonce: 0,
                consumers: 0,
                providers: 0,
                data: AccountData(free: planks, reserved: .zero, frozen: .zero, flags: 0)
            )
        }
        let builder = WalletBalanceBuilder(userDefaults: userDefaults)
        let withoutTestnetFunds = try XCTUnwrap(
            builder.buildBalance(for: before, [scenario.wallet], scenario.catalog)?[scenario.wallet.metaId]
        )
        let withTestnetFunds = try XCTUnwrap(
            builder.buildBalance(for: after, [scenario.wallet], scenario.catalog)?[scenario.wallet.metaId]
        )

        XCTAssertGreaterThan(withoutTestnetFunds.enabledAssetFiatBalance, 0)
        XCTAssertEqual(withTestnetFunds.enabledAssetFiatBalance, withoutTestnetFunds.enabledAssetFiatBalance)
        XCTAssertEqual(withTestnetFunds.totalFiatValue, withoutTestnetFunds.totalFiatValue)
        XCTAssertEqual(withTestnetFunds.exclusions.testnetCount, withoutTestnetFunds.exclusions.testnetCount + 3)
        XCTAssertEqual(withTestnetFunds.exclusions.unpricedCount, withoutTestnetFunds.exclusions.unpricedCount)

        let viewModel = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
            .buildViewModel(
                wallet: scenario.wallet,
                chainAssets: scenario.catalog,
                locale: locale,
                accountInfos: after,
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil
            )
        let testnetChainIds = Set(testnetAssets.map(\.chain.chainId))
        XCTAssertFalse(viewModel.networkSections.contains { testnetChainIds.contains($0.chainId) })
        // Subtotals are formatted to cents, so they add up to the header within a cent each.
        let subtotals = viewModel.networkSections.compactMap(\.fiatSubtotal).compactMap(decimal)
        XCTAssertEqual(
            NSDecimalNumber(decimal: subtotals.reduce(0, +)).doubleValue,
            NSDecimalNumber(decimal: withTestnetFunds.enabledAssetFiatBalance).doubleValue,
            accuracy: 0.01 * Double(subtotals.count)
        )
        XCTAssertTrue(viewModel.exclusions.contains { $0.kind == .testnetAssets })
    }

    func testHiddenNeverLoadedDoesNotBlockIsLoaded() throws {
        let chain = makeChain(name: "Cold")
        let loaded = makeChainAsset(chain: chain, symbol: "LDD", price: 1)
        let neverLoaded = makeChainAsset(chain: chain, symbol: "NVR", price: 1)
        let wallet = AccountGenerator.generateMetaAccount()
        // `neverLoaded` has no entry at all: its network never answered.
        let accountInfos = balances(wallet: wallet, [loaded: (2, 0, 0)])

        // As in 4.0.4, an asset that was never looked up does not hold the total back, counted
        // or hidden, so one silent network cannot leave the header loading forever.
        XCTAssertEqual(try header(wallet, [loaded, neverLoaded], accountInfos).enabledAssetFiatBalance, 2)

        hide(neverLoaded, in: wallet)
        let balance = try header(wallet, [loaded, neverLoaded], accountInfos)

        XCTAssertEqual(balance.enabledAssetFiatBalance, 2)
        XCTAssertEqual(balance.exclusions.hiddenCount, 0, "a hidden asset without a balance is not reported")
    }

    func testHiddenSummaryCountsAndSums() {
        let chain = makeChain(name: "Summary")
        let first = makeChainAsset(chain: chain, symbol: "ONE", price: 2)
        let second = makeChainAsset(chain: chain, symbol: "TWO")
        let empty = makeChainAsset(chain: chain, symbol: "NIL", price: 7)
        let shown = makeChainAsset(chain: chain, symbol: "SHW", price: 1)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(
            wallet: wallet,
            [first: (3, 1, 0), second: (8, 0, 0), empty: (0, 0, 0), shown: (1, 0, 0)]
        )
        for chainAsset in [first, second, empty] {
            hide(chainAsset, in: wallet)
        }

        let summary = WalletBalanceBuilder().hiddenSummary(
            wallet: wallet,
            chainAssets: [first, second, empty, shown],
            accountInfos: accountInfos
        )

        XCTAssertEqual(summary.count, 2, "the funded hidden assets, priced or not")
        XCTAssertEqual(summary.fiat, 8, "4 × 2: the unpriced hidden holding adds nothing")
    }

    // MARK: - Header scope (critique C4)

    func testHeaderIsWalletWideUnderANetworkFilterWithShowingCaption() throws {
        let alpha = makeChain(name: "Alpha")
        let beta = makeChain(name: "Beta")
        let alphaAsset = makeChainAsset(chain: alpha, symbol: "ALP", price: 2)
        let betaAsset = makeChainAsset(chain: beta, symbol: "BET", price: 3)
        let generated = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: generated, [alphaAsset: (10, 0, 0), betaAsset: (10, 0, 0)])
        let builder = WalletBalanceBuilder()
        let factory = BalanceInfoViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())

        let filtered = generated.replacingNetworkManagmentFilter(alpha.chainId)
        let filteredBalances = try XCTUnwrap(
            builder.buildPortfolioHeaderBalance(
                for: accountInfos,
                wallet: filtered,
                chainAssets: [alphaAsset, betaAsset]
            )
        )
        let filteredInfo = try XCTUnwrap(filteredBalances[filtered.metaId])
        XCTAssertEqual(filteredInfo.enabledAssetFiatBalance, 50, "the filter never scopes the total")
        XCTAssertEqual(filteredInfo.filteredPart?.fiatBalance, 20)
        let filteredViewModel = factory.buildBalanceInfo(
            with: .networkManagement(wallet: filtered),
            balances: filteredBalances,
            infoButtonEnabled: false,
            locale: locale
        )
        XCTAssertEqual(filteredViewModel.balanceString, "$50")
        let expectedCaption = FWAppearance.walletHeaderRestyled
            ? "Showing Alpha · $20"
            : PortfolioTestCopy.text("portfolio.header.showing_filtered", "Alpha", "$20")
        XCTAssertEqual(filteredViewModel.filteredPartString, expectedCaption)

        let all = generated.replacingNetworkManagmentFilter(NetworkManagmentFilter.all.identifier)
        let allBalances = try XCTUnwrap(
            builder.buildPortfolioHeaderBalance(for: accountInfos, wallet: all, chainAssets: [alphaAsset, betaAsset])
        )
        XCTAssertNil(allBalances[all.metaId]?.filteredPart)
        let allViewModel = factory.buildBalanceInfo(
            with: .networkManagement(wallet: all),
            balances: allBalances,
            infoButtonEnabled: false,
            locale: locale
        )
        XCTAssertEqual(allViewModel.balanceString, "$50")
        XCTAssertNil(allViewModel.filteredPartString)
    }

    // MARK: - Rows add up to the header

    func testSumOfSubtotalsEqualsHeaderTotal() throws {
        let staking = makeChain(name: "Staking", options: [.poolStaking])
        let tokens = makeChain(name: "Tokens")
        let hiddenOnly = makeChain(name: "Hidden only")
        let testnet = makeChain(name: "Testnet", options: [.testnet])
        let native = makeChainAsset(chain: staking, symbol: "NAT", price: 2, isUtility: true, isNative: true)
        let stable = makeChainAsset(chain: tokens, symbol: "USD", price: 1)
        let raw = makeChainAsset(chain: tokens, symbol: "RAW")
        let hiddenStable = makeChainAsset(chain: tokens, symbol: "HUSD", price: 1)
        let hiddenToken = makeChainAsset(chain: hiddenOnly, symbol: "HID", price: 10)
        let testToken = makeChainAsset(chain: testnet, symbol: "TST", price: 10)
        let chainAssets = [native, stable, raw, hiddenStable, hiddenToken, testToken]
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, [
            native: (100, 900, 100),
            stable: (30, 0, 0),
            raw: (5, 0, 0),
            hiddenStable: (7, 0, 0),
            hiddenToken: (1, 0, 0),
            testToken: (1, 0, 0)
        ])
        for chainAsset in [hiddenStable, hiddenToken] {
            hide(chainAsset, in: wallet)
        }

        let balance = try header(wallet, chainAssets, accountInfos)
        let viewModel = buildList(wallet, chainAssets, accountInfos)

        let subtotals = viewModel.networkSections.compactMap(\.fiatSubtotal).compactMap(decimal)
        XCTAssertEqual(subtotals.reduce(0, +), balance.enabledAssetFiatBalance)
        XCTAssertEqual(balance.enabledAssetFiatBalance, 2030)
        XCTAssertEqual(viewModel.networkSections.map(\.networkName), ["Staking", "Tokens"])
        XCTAssertEqual(balance.totalFiatValue, 2047)
        XCTAssertEqual(viewModel.exclusions, [
            PortfolioExclusionCaption(kind: .hiddenAssets, text: PortfolioTestCopy.text("portfolio.exclusions.hidden.other", 2)),
            PortfolioExclusionCaption(kind: .testnetAssets, text: PortfolioTestCopy.text("portfolio.exclusions.testnet.one", 1)),
            PortfolioExclusionCaption(kind: .unpricedAssets, text: PortfolioTestCopy.text("portfolio.exclusions.unpriced.one", 1)),
            PortfolioExclusionCaption(kind: .poolStakes, text: PortfolioTestCopy.text("portfolio.exclusions.pool_stakes"))
        ])
    }

    func testExclusionCaptionsAreWalletWideUnderANetworkFilter() {
        let alpha = makeChain(name: "Alpha")
        let beta = makeChain(name: "Beta")
        let visible = makeChainAsset(chain: alpha, symbol: "ALP", price: 1)
        let hiddenElsewhere = makeChainAsset(chain: beta, symbol: "BET", price: 1)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, [visible: (1, 0, 0), hiddenElsewhere: (1, 0, 0)])
        hide(hiddenElsewhere, in: wallet)

        let viewModel = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
            .buildViewModel(
                wallet: wallet,
                chainAssets: [visible, hiddenElsewhere],
                locale: locale,
                accountInfos: accountInfos,
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .chain,
                chainSettings: [],
                networkFilter: .chain(alpha.chainId),
                search: nil
            )

        XCTAssertEqual(viewModel.exclusions.map(\.kind), [.hiddenAssets])
    }

    // MARK: - Wallet cards

    func testWalletCardsShowEveryHoldingLabelledInclHidden() throws {
        let chain = makeChain(name: "Cards")
        let hidden = makeChainAsset(chain: chain, symbol: "ALL", price: 4)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, [hidden: (5, 0, 0)])
        hide(hidden, in: wallet)
        let balances = try XCTUnwrap(WalletBalanceBuilder().buildBalance(for: accountInfos, [wallet], [hidden]))

        let cards = WalletsManagmentViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            accountScoreFetcher: AccountStatisticsFetchingStub()
        ).buildViewModel(
            viewType: .wallets,
            from: [ManagedMetaAccountModel(info: wallet)],
            balances: balances,
            locale: locale
        )

        XCTAssertEqual(balances[wallet.metaId]?.enabledAssetFiatBalance, 0, "the portfolio header shows none of it")
        XCTAssertEqual(cards.first?.fiatBalance, "$20")
        XCTAssertEqual(cards.first?.balanceCaption, PortfolioTestCopy.text("portfolio.balance.incl_hidden"))
    }

    // MARK: - Upgrades from App Store 4.0.4

    /// A 4.0.4 wallet that hid nothing by hand: the release's header equals what 4.0.4 showed,
    /// computed by the shipped formula (`WalletBalanceBuilder@195b02307`: drop rows stored
    /// `hidden == true`, sum total × price over the rest).
    func testParityWith404Formula() throws {
        let scenario = try LegacyVisibilityScenario(fixture: "404-regular-scanned", userDefaults: userDefaults)
        let funded = scenario.catalog.filter(scenario.isFunded)
        XCTAssertEqual(funded.count, scenario.fixture.balances.count)
        try upsertPrices(for: funded)

        scenario.migrate()
        let accountInfos = Self.lookedUp(scenario)
        let balance = try XCTUnwrap(
            WalletBalanceBuilder(userDefaults: userDefaults)
                .buildBalance(for: accountInfos, [scenario.wallet], scenario.catalog)?[scenario.wallet.metaId]
        )

        let shipped = Self.shipped404Total(
            wallet: scenario.wallet,
            chainAssets: scenario.catalog,
            accountInfos: accountInfos
        )
        XCTAssertGreaterThan(shipped, 0)
        XCTAssertEqual(balance.enabledAssetFiatBalance, shipped)
        XCTAssertEqual(balance.totalFiatValue, shipped)
        XCTAssertEqual(balance.exclusions.hiddenCount, 0)
        XCTAssertNil(balance.allHoldingsCaption)
    }

    /// A 4.0.4 TON wallet's own hide of a jetton that holds funds stays Hidden after the upgrade
    /// (IOSUX-6): it leaves the header, is labelled under the list, and wallet management still
    /// reports it.
    func testTon404FundedHideIsExcludedLabelledAndCountedInWalletManagement() throws {
        let metaId = "iosux7-ton-\(UUID().uuidString)"
        let scenario = try LegacyVisibilityScenario(fixture: "404-ton-optout", userDefaults: .standard, metaId: metaId)
        defer { scenario.removeStoredState() }
        let ton = try XCTUnwrap(scenario.asset(byNetwork: "TON Mainnet", symbol: "ton"))
        try upsertPrices(for: [ton])

        scenario.migrate()
        let balance = try XCTUnwrap(
            WalletBalanceBuilder()
                .buildBalance(
                    for: Self.lookedUp(scenario),
                    [scenario.wallet],
                    scenario.catalog
                )?[scenario.wallet.metaId]
        )
        let viewModel = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
            .buildViewModel(
                wallet: scenario.wallet,
                chainAssets: scenario.catalog,
                locale: locale,
                accountInfos: scenario.accountInfos,
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil
            )

        let tonFiat = Self.price(for: ton) * 3
        XCTAssertEqual(balance.enabledAssetFiatBalance, tonFiat)
        XCTAssertEqual(balance.exclusions.hiddenCount, 1, "jetton A; jetton B is hidden but empty")
        XCTAssertEqual(balance.exclusions.unpricedCount, 2, "jettons C and D have no price")
        XCTAssertEqual(balance.totalFiatValue, tonFiat, "the hidden jetton has no price to add")
        XCTAssertNil(balance.allHoldingsCaption, "nothing hidden adds to the wallet total")
        XCTAssertEqual(viewModel.exclusions.map(\.text), [
            PortfolioTestCopy.text("portfolio.exclusions.hidden.one", 1),
            PortfolioTestCopy.text("portfolio.exclusions.unpriced.other", 2)
        ])
        XCTAssertFalse(viewModel.networkSections.flatMap(\.rows).contains { $0.chainAsset.asset.name == "Jetton A" })

        // The one-time notice names the funded hide the previous version kept, until the user
        // keeps it hidden; nothing is unhidden.
        let jettonA = try XCTUnwrap(scenario.extraAssets.first { $0.asset.name == "Jetton A" })
        XCTAssertEqual(viewModel.hiddenFundsNotice?.title, PortfolioTestCopy.text("portfolio.hidden_funds.title.one", 1))
        XCTAssertEqual(viewModel.hiddenFundsNotice?.assetKeys, [jettonA.assetKey])
        AssetVisibilityPreferenceStore.markHiddenFundsReviewed([jettonA.assetKey], walletId: scenario.wallet.metaId)
        XCTAssertNil(
            ChainAssetListViewModelFactory.hiddenFundsNotice(for: balance.exclusions, walletId: scenario.wallet.metaId)
        )
        XCTAssertEqual(scenario.preference(jettonA), .hidden)
        XCTAssertEqual(balance.exclusions.hiddenFundedAssetKeys, [jettonA.assetKey])
    }

    /// A funded asset hidden in this version is labelled under the list, but raises no notice:
    /// the user hid it knowing it holds funds.
    func testHideMadeInThisVersionRaisesNoHiddenFundsNotice() {
        let chain = makeChain(name: "Current")
        let asset = makeChainAsset(chain: chain, symbol: "CUR", price: 1)
        let wallet = AccountGenerator.generateMetaAccount()
        let accountInfos = balances(wallet: wallet, [asset: (3, 0, 0)])
        hide(asset, in: wallet)

        let viewModel = buildList(wallet, [asset], accountInfos)

        XCTAssertEqual(viewModel.exclusions.map(\.kind), [.hiddenAssets])
        XCTAssertNil(viewModel.hiddenFundsNotice)
    }
}

// MARK: - Helpers

private extension WalletBalanceTotalsTests {
    /// The fixture balances plus an empty entry for every other asset the wallet has an
    /// account for: the state once every network has been looked up.
    static func lookedUp(_ scenario: LegacyVisibilityScenario) -> [ChainAssetKey: AccountInfo?] {
        var accountInfos = scenario.accountInfos
        for chainAsset in scenario.catalog {
            guard let accountId = scenario.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                continue
            }
            let key = chainAsset.uniqueKey(accountId: accountId)
            if accountInfos[key] == nil {
                accountInfos[key] = .some(nil)
            }
        }
        return accountInfos
    }

    /// `WalletBalanceBuilder@195b02307` (App Store 4.0.4): rows stored `hidden == true` for the
    /// asset's exact identifier are left out; every other asset adds total × price.
    static func shipped404Total(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?]
    ) -> Decimal {
        chainAssets.reduce(Decimal.zero) { result, chainAsset in
            let hidden = wallet.assetsVisibility.first { $0.assetId == chainAsset.identifier }?.hidden == true
            guard !hidden,
                  let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
                  let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] ?? nil,
                  let priceData = chainAsset.asset.getPrice(for: wallet.selectedCurrency),
                  let price = Decimal(string: priceData.price),
                  let amount = Decimal.fromSubstrateAmount(
                      accountInfo.data.total,
                      precision: chainAsset.asset.displayInfo.assetPrecision
                  ) else {
                return result
            }
            return result + amount * price
        }
    }

    /// Distinct whole-dollar prices, so a mix-up between two assets changes the total.
    func upsertPrices(for chainAssets: [ChainAsset]) throws {
        let currency = Currency.defaultCurrency()
        let priceIds = try chainAssets.map { try XCTUnwrap($0.asset.priceId, $0.identifier) }
        ExactAssetPriceCache.shared.upsert(Set(priceIds).sorted().enumerated().map { index, priceId in
            PriceData(
                currencyId: currency.id,
                priceId: priceId,
                price: String(index + 2),
                fiatDayChange: nil,
                coingeckoPriceId: priceId
            )
        })
    }

    static func price(for chainAsset: ChainAsset) -> Decimal {
        chainAsset.asset.getPrice(for: Currency.defaultCurrency()).flatMap { Decimal(string: $0.price) } ?? .zero
    }

    func header(
        _ wallet: MetaAccountModel,
        _ chainAssets: [ChainAsset],
        _ accountInfos: [ChainAssetKey: AccountInfo?]
    ) throws -> WalletBalanceInfo {
        try XCTUnwrap(WalletBalanceBuilder().buildBalance(for: accountInfos, [wallet], chainAssets)?[wallet.metaId])
    }

    func buildList(
        _ wallet: MetaAccountModel,
        _ chainAssets: [ChainAsset],
        _ accountInfos: [ChainAssetKey: AccountInfo?]
    ) -> ChainAssetListViewModel {
        ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
            .buildViewModel(
                wallet: wallet,
                chainAssets: chainAssets,
                locale: locale,
                accountInfos: accountInfos,
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: nil,
                search: nil
            )
    }

    /// Explicit Hidden in the standard store, which the list and the price trust read.
    func hide(_ chainAsset: ChainAsset, in wallet: MetaAccountModel) {
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: chainAsset.assetKey)
        standardPreferences.append((wallet.metaId, chainAsset.assetKey))
    }

    func attributedText(_ state: ShimmeredLabelState) -> String? {
        switch state {
        case let .normalAttributed(text), let .updatingAttributed(text):
            return text?.string
        case let .normal(text), let .updating(text):
            return text
        case .stopShimmering:
            return nil
        }
    }

    func decimal(_ fiat: String) -> Decimal? {
        Decimal(string: fiat.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: ""))
    }

    func makeChain(name: String, options: [ChainOptions]? = nil) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: UUID().uuidString.lowercased(),
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

    /// A registry asset with precision 0 and, when `price` is given, a price under a unique id.
    func makeChainAsset(
        chain: ChainModel,
        symbol: String,
        price: Decimal? = nil,
        isUtility: Bool = false,
        isNative: Bool = false
    ) -> ChainAsset {
        let id = "\(symbol.lowercased())-\(UUID().uuidString.lowercased())"
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

        if let price, let priceId = asset.priceId {
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

    /// (free, reserved, frozen) per asset.
    func balances(
        wallet: MetaAccountModel,
        _ values: [ChainAsset: (UInt64, UInt64, UInt64)]
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
                    data: AccountData(
                        free: BigUInt(value.0),
                        reserved: BigUInt(value.1),
                        frozen: BigUInt(value.2),
                        flags: 0
                    )
                )
            )
        })
    }
}

/// IOSUX-7 views: the Transferable line, the exclusion captions above Manage assets, the
/// hidden-funds notice and the header's "Showing …" caption.
final class PortfolioTotalsViewTests: XCTestCase {
    func testRowShowsTransferableLineOnlyWhenItDiffers() throws {
        let cell = ChainAccountBalanceTableCell(style: .default, reuseIdentifier: nil)
        let chainAsset = try XCTUnwrap(UniversalWalletRegistry.tairaChainModel.chainAssets.first)

        cell.bind(to: rowModel(chainAsset, transferable: "Transferable 10.000"))
        let label = try XCTUnwrap(labels(in: cell).first { $0.text == "Transferable 10.000" })
        XCTAssertFalse(label.isHidden)

        cell.bind(to: rowModel(chainAsset, transferable: nil))
        XCTAssertTrue(label.isHidden)
    }

    func testExclusionCaptionsSitAboveManageAssetsAndHiddenOneOpensManage() throws {
        let layout = ChainAssetListViewLayout(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        layout.layoutIfNeeded()
        var tappedHidden = 0
        var tappedTestnet = 0
        layout.exclusionsView.onTapHiddenAssets = { tappedHidden += 1 }
        layout.exclusionsView.onTapTestnetAssets = { tappedTestnet += 1 }

        layout.setFooterView()
        let plainHeight = try XCTUnwrap(layout.tableView.tableFooterView).frame.height

        layout.exclusionsView.bind(captions: ChainAssetListViewModelFactory.exclusionCaptions(for: PortfolioExclusions(
            hiddenCount: 2,
            testnetCount: 1,
            unpricedCount: 1,
            poolStakesExcluded: true
        )))
        layout.setFooterView()

        let footer = try XCTUnwrap(layout.tableView.tableFooterView)
        XCTAssertGreaterThan(footer.frame.height, plainHeight)
        XCTAssertEqual(layout.exclusionsView.captions.map(\.text), [
            PortfolioTestCopy.text("portfolio.exclusions.hidden.other", 2),
            PortfolioTestCopy.text("portfolio.exclusions.testnet.one", 1),
            PortfolioTestCopy.text("portfolio.exclusions.unpriced.one", 1),
            PortfolioTestCopy.text("portfolio.exclusions.pool_stakes")
        ])
        let buttonTitles = buttons(in: layout.exclusionsView).map { $0.title(for: .normal) }
        XCTAssertEqual(
            labels(in: layout.exclusionsView).compactMap(\.text).filter { !buttonTitles.contains($0) },
            [PortfolioTestCopy.text("portfolio.exclusions.unpriced.one", 1), PortfolioTestCopy.text("portfolio.exclusions.pool_stakes")]
        )
        let manageButtons = buttons(in: layout.exclusionsView)
        XCTAssertEqual(
            manageButtons.map { $0.title(for: .normal) },
            [PortfolioTestCopy.text("portfolio.exclusions.hidden.other", 2), PortfolioTestCopy.text("portfolio.exclusions.testnet.one", 1)]
        )
        manageButtons.forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertEqual(tappedHidden, 1)
        XCTAssertEqual(tappedTestnet, 1)

        layout.exclusionsView.bind(captions: [])
        XCTAssertTrue(layout.exclusionsView.isHidden)
    }

    func testHiddenFundsNoticeShowsAndKeepHiddenReportsBack() {
        let view = PortfolioHiddenFundsNoticeView()
        var kept = 0
        var reviewed = 0
        view.onKeepHidden = { kept += 1 }
        view.onReview = { reviewed += 1 }

        view.bind(nil)
        XCTAssertTrue(view.isHidden)

        view.bind(PortfolioHiddenFundsNotice(assetKeys: [], title: "1 hidden asset holds funds", message: "Hidden assets"))
        XCTAssertFalse(view.isHidden)
        XCTAssertTrue(labels(in: view).contains { $0.text == "1 hidden asset holds funds" })
        view.keepHiddenButton.sendActions(for: .touchUpInside)
        view.reviewButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(kept, 1)
        XCTAssertEqual(reviewed, 1)
    }

    func testHeaderShowsFilteredPartOnlyUnderAFilter() throws {
        let layout = BalanceInfoViewLayout()

        layout.bind(viewModel: BalanceInfoViewModel(
            dayChangeAttributedString: nil,
            balanceString: "$50",
            infoButtonEnabled: false,
            filteredPartString: "Showing Alpha · $20"
        ))
        let caption = try XCTUnwrap(labels(in: layout).first { $0.text == "Showing Alpha · $20" })
        XCTAssertFalse(caption.isHidden)

        layout.bind(viewModel: BalanceInfoViewModel(
            dayChangeAttributedString: nil,
            balanceString: "$50",
            infoButtonEnabled: false
        ))
        XCTAssertTrue(caption.isHidden)
    }

    /// The English copy is the portfolio contract's (§3, §5, §9), and every localisation the app
    /// ships has every key, translated, with the same format specifiers, so no shipped language
    /// falls back to English or crashes on a format.
    func testPortfolioValueCopyIsTranslatedInEveryShippedLocalization() throws {
        let english = try Self.strings(for: "en")
        XCTAssertEqual(
            PortfolioTestCopy.keys.reduce(into: [String: String]()) { $0[$1] = english[$1] },
            [
                "portfolio.balance.incl_hidden": "incl. hidden",
                "portfolio.header.showing_filtered": "Showing %@ · %@",
                "portfolio.asset.transferable": "Transferable %@",
                "portfolio.asset.testnet_no_value": "No value",
                "portfolio.asset.price_unavailable": "Price unavailable",
                "portfolio.exclusions.hidden.one": "%d hidden asset not included · Manage",
                "portfolio.exclusions.hidden.other": "%d hidden assets not included · Manage",
                "portfolio.exclusions.testnet.one": "%d testnet asset not included · Manage",
                "portfolio.exclusions.testnet.other": "%d testnet assets not included · Manage",
                "portfolio.exclusions.unpriced.one": "%d asset without price not included",
                "portfolio.exclusions.unpriced.other": "%d assets without price not included",
                "portfolio.exclusions.pool_stakes": "Pool stakes not included",
                "portfolio.hidden_funds.title.one": "%d hidden asset holds funds",
                "portfolio.hidden_funds.title.other": "%d hidden assets hold funds",
                "portfolio.hidden_funds.message":
                    "Hidden assets are not included in your total. Review them, or keep them hidden.",
                "portfolio.hidden_funds.review": "Review",
                "portfolio.hidden_funds.keep_hidden": "Keep hidden"
            ]
        )

        let localizations = Bundle.main.localizations.filter { $0 != "Base" && $0 != "en" }
        XCTAssertTrue(Set(["ru", "ja", "zh-Hans", "vi", "pt-PT", "tr", "id"]).isSubset(of: Set(localizations)))
        for localization in localizations {
            let table = try Self.strings(for: localization)
            for key in PortfolioTestCopy.keys {
                let englishValue = try XCTUnwrap(english[key], key)
                let value = try XCTUnwrap(table[key], "\(localization): \(key) is missing")
                XCTAssertNotEqual(value, englishValue, "\(localization): \(key) is English")
                XCTAssertEqual(
                    Self.formatSpecifiers(value),
                    Self.formatSpecifiers(englishValue),
                    "\(localization): \(key)"
                )
            }
        }
    }

    private static func strings(for localization: String) throws -> [String: String] {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: localization),
            localization
        )
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String], localization)
    }

    private static func formatSpecifiers(_ format: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: "%(?:[0-9]+\\$)?[@d]")
        let range = NSRange(format.startIndex..., in: format)
        return (regex?.matches(in: format, range: range) ?? []).compactMap { match in
            Range(match.range, in: format).map { String(format[$0]) }
        }.sorted()
    }

    private func rowModel(_ chainAsset: ChainAsset, transferable: String?) -> ChainAccountBalanceCellViewModel {
        ChainAccountBalanceCellViewModel(
            assetContainsChainAssets: [chainAsset],
            chainIconViewViewModel: ChainCollectionViewModel(maxImagesCount: 3, chainImages: []),
            chainAsset: chainAsset,
            metadataTrust: AssetMetadataTrustInfo(trust: .verified, provenance: .registry),
            assetName: "Asset",
            assetInfo: nil,
            imageViewModel: nil,
            balanceString: .normal("1000.000"),
            priceAttributedString: .normalAttributed(nil),
            totalAmountString: .normal("$3,000"),
            options: nil,
            isColdBoot: false,
            locale: Locale(identifier: "en_US"),
            hideButtonIsVisible: false,
            swipeActionsEnabled: false,
            transferableString: transferable
        )
    }

    private func labels(in view: UIView) -> [UILabel] {
        view.subviews.flatMap { subview -> [UILabel] in
            guard let label = subview as? UILabel else {
                return labels(in: subview)
            }
            return [label]
        }
    }

    private func buttons(in view: UIView) -> [UIButton] {
        view.subviews.flatMap { subview -> [UIButton] in
            guard let button = subview as? UIButton else {
                return buttons(in: subview)
            }
            return [button]
        }
    }
}

/// The portfolio value copy as the app shows it. These strings follow the system language
/// (`NSLocalizedString`, like the rest of this release's new copy), and the test simulators may
/// run in any language, so assertions compare against the app's own table;
/// `testPortfolioValueCopyIsTranslatedInEveryShippedLocalization` pins the English wording.
enum PortfolioTestCopy {
    static let keys = [
        "portfolio.balance.incl_hidden",
        "portfolio.header.showing_filtered",
        "portfolio.asset.transferable",
        "portfolio.asset.testnet_no_value",
        "portfolio.asset.price_unavailable",
        "portfolio.exclusions.hidden.one",
        "portfolio.exclusions.hidden.other",
        "portfolio.exclusions.testnet.one",
        "portfolio.exclusions.testnet.other",
        "portfolio.exclusions.unpriced.one",
        "portfolio.exclusions.unpriced.other",
        "portfolio.exclusions.pool_stakes",
        "portfolio.hidden_funds.title.one",
        "portfolio.hidden_funds.title.other",
        "portfolio.hidden_funds.message",
        "portfolio.hidden_funds.review",
        "portfolio.hidden_funds.keep_hidden"
    ]

    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
    }
}

private final class AccountStatisticsFetchingStub: AccountStatisticsFetching {
    func subscribeForStatistics(
        address _: String
    ) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        nil
    }
}
