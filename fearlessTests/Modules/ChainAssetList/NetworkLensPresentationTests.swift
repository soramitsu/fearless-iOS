import BigInt
import SSFModels
import XCTest
@testable import fearless

final class NetworkLensPresentationTests: XCTestCase {
    override func setUp() { super.setUp(); ExactAssetPriceCache.shared.clear() }
    override func tearDown() { ExactAssetPriceCache.shared.clear(); super.tearDown() }

    func testNetworkSearchDropsUnmatchedHeadersAndScopesSubtotalToVisibleRows() throws {
        let alpha = makeChain(name: "Álpha network")
        let beta = makeChain(name: "Beta network")
        let first = makeChainAsset(chain: alpha, id: "first", symbol: "ONE", price: 2)
        let second = makeChainAsset(chain: alpha, id: "second", symbol: "TWO", price: 7)
        let third = makeChainAsset(chain: beta, id: "third", symbol: "THREE", price: 3)
        let wallet = AccountGenerator.generateMetaAccount()
        let assets = [first, second, third]
        let infos = balances(wallet: wallet, values: [first: 10, second: 3, third: 100])
        let factory = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        func build(_ query: String) -> ChainAssetListViewModel {
            factory.buildViewModel(
                wallet: wallet,
                chainAssets: assets,
                locale: Locale(identifier: "en_US"),
                accountInfos: infos,
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .search,
                chainSettings: [],
                networkFilter: nil,
                search: query
            )
        }
        let network = build("alpha")
        XCTAssertEqual(network.networkSections.count, 1)
        XCTAssertEqual(network.networkSections.first?.rows.map { $0.chainAsset.asset.id }, ["second", "first"])
        let single = build("ONE")
        XCTAssertEqual(single.networkSections.count, 1)
        XCTAssertEqual(single.networkSections.first?.rows.map { $0.chainAsset.asset.id }, ["first"])
        let expected = factory.fiatFormatter(for: wallet.selectedCurrency, locale: Locale(identifier: "en_US")).stringFromDecimal(20)
        XCTAssertEqual(single.networkSections.first?.fiatSubtotal, expected)
        XCTAssertTrue(build("no such network").networkSections.isEmpty)
    }

    func testZeroDefaultNetworksAreGroupedButSingleNetworkStaysDirect() throws {
        let chain = makeChain(name: "Ranked", rank: 1)
        let asset = makeChainAsset(chain: chain, id: "zero", symbol: "ZERO", isUtility: true, isNative: true)
        let wallet = AccountGenerator.generateMetaAccount()
        let factory = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory(), zeroDefaults: PortfolioZeroDefaultList(entries: []))
        func build(_ filter: NetworkManagmentFilter?) -> ChainAssetListViewModel {
            factory.buildViewModel(
                wallet: wallet,
                chainAssets: [asset],
                locale: Locale(identifier: "en_US"),
                accountInfos: balances(wallet: wallet, values: [asset: 0]),
                chainsWithIssue: [],
                shouldRunManageAssetAnimate: false,
                displayType: .assetChains,
                chainSettings: [],
                networkFilter: filter,
                search: nil
            )
        }
        let all = build(nil)
        XCTAssertEqual(all.walletId, wallet.metaId)
        XCTAssertEqual(all.networkSections.first?.kind, .zeroNetworks(count: 1))
        XCTAssertEqual(all.networkSections.last?.parentSectionId, all.networkSections.first?.id)
        let one = build(.chain(chain.chainId))
        XCTAssertEqual(one.networkSections.count, 1)
        XCTAssertNil(one.networkSections.first?.parentSectionId)
    }

    func testPopularSearchExcludesTestnets() {
        let main = makeChain(name: "Main", rank: 1)
        let test = makeChain(name: "Test", rank: 2, options: [.testnet])
        let first = makeChainAsset(chain: main, id: "main", symbol: "COIN")
        let second = makeChainAsset(chain: test, id: "test", symbol: "COIN")
        let factory = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        let result = factory.filterChainAssets(with: .popular, chainAssets: [first, second], wallet: AccountGenerator.generateMetaAccount(), search: nil)
        XCTAssertEqual(result.map { $0.asset.id }, ["main"])
    }

    func testPresentationStateSurvivesReopenAndStaysWalletScoped() throws {
        let suite = "portfolio-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PortfolioCollapseStore(userDefaults: defaults)
        XCTAssertEqual(store.lens(walletId: "first"), .token)
        store.setLens(.network, walletId: "first")
        store.setIdentifiers(["chain-a"], walletId: "first", kind: "network")
        let reopened = PortfolioCollapseStore(userDefaults: defaults)
        XCTAssertEqual(reopened.lens(walletId: "first"), .network)
        XCTAssertEqual(reopened.identifiers(walletId: "first", kind: "network"), ["chain-a"])
        XCTAssertEqual(reopened.lens(walletId: "second"), .token)
        XCTAssertTrue(reopened.identifiers(walletId: "second", kind: "network").isEmpty)
        defaults.set([1, 2], forKey: "portfolio.collapsed:first:network")
        defaults.set("invalid", forKey: "portfolio.lens:first")
        XCTAssertTrue(reopened.identifiers(walletId: "first", kind: "network").isEmpty)
        XCTAssertEqual(reopened.lens(walletId: "first"), .token)
    }

    // MARK: - One list

    private func oneList(
        _ factory: ChainAssetListViewModelFactory = ChainAssetListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        ),
        wallet: MetaAccountModel,
        assets: [ChainAsset],
        infos: [ChainAssetKey: AccountInfo?],
        filter: NetworkManagmentFilter? = nil,
        search: String? = nil
    ) -> ChainAssetListViewModel {
        factory.buildViewModel(
            wallet: wallet,
            chainAssets: assets,
            locale: Locale(identifier: "en_US"),
            accountInfos: infos,
            chainsWithIssue: [],
            shouldRunManageAssetAnimate: false,
            displayType: search == nil ? (filter?.isChainSelected == true ? .chain : .assetChains) : .search,
            chainSettings: [],
            networkFilter: filter,
            search: search,
            lens: .token
        )
    }

    func testOneListNetworkChipsRankHoldingsAndRetainSelectedFilters() {
        let alpha = makeChain(name: "Alpha")
        let beta = makeChain(name: "Beta")
        let zero = makeChain(name: "Zero")
        let hiddenChain = makeChain(name: "Hidden")
        let testnet = makeChain(name: "Testnet", options: [.testnet])
        let first = makeChainAsset(chain: alpha, id: "one", symbol: "ONE", price: 2)
        let second = makeChainAsset(chain: beta, id: "two", symbol: "TWO", price: 3)
        let third = makeChainAsset(chain: zero, id: "zero", symbol: "ZERO", price: 1)
        let hidden = makeChainAsset(chain: hiddenChain, id: "hide", symbol: "HIDE", price: 50)
        let test = makeChainAsset(chain: testnet, id: "test", symbol: "TEST")
        let wallet = AccountGenerator.generateMetaAccount()
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: hidden.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: hidden.assetKey) }
        let infos = balances(wallet: wallet, values: [first: 10, second: 20, third: 0, hidden: 5, test: 9])
        let factory = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        let chips = factory.networkChips(
            chainAssets: [first, second, third, second, hidden, test],
            accountInfos: infos,
            wallet: wallet,
            filter: .all,
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(chips.map(\.id), ["all", beta.chainId, alpha.chainId], "Largest holding first; no zero, hidden or testnet chip")
        XCTAssertEqual(chips.first?.title, "All networks")
        XCTAssertEqual(chips.filter(\.selected).map(\.id), ["all"])
        XCTAssertEqual(
            factory.networkChips(chainAssets: [first, second], accountInfos: infos, wallet: wallet, filter: nil, locale: Locale(identifier: "ja"))
                .first?.title,
            "すべてのネットワーク"
        )
        for (filter, title) in [(NetworkManagmentFilter.popular, "Popular"), (.favourite, "Favorites"), (.chain(zero.chainId), "Zero")] {
            let filtered = factory.networkChips(
                chainAssets: [first, second, third],
                accountInfos: infos,
                wallet: wallet,
                filter: filter,
                locale: Locale(identifier: "en")
            )
            XCTAssertEqual(filtered.filter(\.selected).map(\.id), [filter.identifier])
            XCTAssertEqual(filtered.first(where: \.selected)?.title, title)
            XCTAssertTrue(filtered.contains { $0.id == beta.chainId }, "Filters must not hide the other funded-network chips")
        }
        // The list model carries the chips for its own filter.
        let model = oneList(factory, wallet: wallet, assets: [first, second], infos: infos, filter: .chain(alpha.chainId))
        XCTAssertEqual(model.networkChips.filter(\.selected).map(\.id), [alpha.chainId])
        XCTAssertEqual(model.tokenRows.map(\.model.symbol), ["ONE"])
    }

    func testOneListSearchFindsTokensBySymbolNameAndNetworkAndKeepsHiddenAssetsOut() {
        let alpha = makeChain(name: "Alpha chain")
        let gamma = makeChain(name: "Gamma chain")
        let quartz = makeChainAsset(chain: alpha, id: "xqz", symbol: "XQZ", name: "Quartz token", price: 2)
        let pearl = makeChainAsset(chain: gamma, id: "prl", symbol: "PRL", name: "Pearl", price: 1)
        let hidden = makeChainAsset(chain: gamma, id: "hdn", symbol: "HDN", name: "Hidden quartz", price: 4)
        let wallet = AccountGenerator.generateMetaAccount()
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: hidden.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: hidden.assetKey) }
        let assets = [quartz, pearl, hidden]
        let infos = balances(wallet: wallet, values: [quartz: 10, pearl: 3, hidden: 7])
        func symbols(_ search: String?) -> [String] {
            oneList(wallet: wallet, assets: assets, infos: infos, search: search).tokenRows.map(\.model.symbol)
        }
        XCTAssertEqual(symbols(nil), ["XQZ", "PRL"], "Hidden assets stay out of the list")
        XCTAssertEqual(symbols("xqz"), ["XQZ"], "By symbol, any case")
        XCTAssertEqual(symbols("quartz"), ["XQZ"], "By name; the hidden Hidden quartz stays out")
        XCTAssertEqual(symbols("PEAR"), ["PRL"])
        XCTAssertEqual(symbols("gamma"), ["PRL"], "By network name")
        XCTAssertEqual(symbols("hdn"), [], "A hidden asset is found in Manage assets, not here")
        let nothing = oneList(wallet: wallet, assets: assets, infos: infos, search: "hdn")
        XCTAssertTrue(nothing.searchFoundNothing)
        XCTAssertFalse(nothing.canSearchAllNetworks)
        XCTAssertTrue(nothing.exclusions.isEmpty, "A search shows no exclusion captions")
        XCTAssertFalse(oneList(wallet: wallet, assets: assets, infos: infos).exclusions.isEmpty, "Hidden caption")
    }

    func testOneListZeroBalancesAreListedOnlyWhenSearched() {
        let funded = makeChain(name: "Funded")
        let ranked = makeChain(name: "Ranked", rank: 1)
        let coin = makeChainAsset(chain: funded, id: "coin", symbol: "COIN", price: 2)
        let zero = makeChainAsset(chain: ranked, id: "zero", symbol: "ZERO", isUtility: true, isNative: true)
        let wallet = AccountGenerator.generateMetaAccount()
        let factory = ChainAssetListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            zeroDefaults: PortfolioZeroDefaultList(entries: [])
        )
        let infos = balances(wallet: wallet, values: [coin: 5, zero: 0])
        let home = oneList(factory, wallet: wallet, assets: [coin, zero], infos: infos)
        XCTAssertEqual(home.tokenRows.map(\.model.symbol), ["COIN"])
        XCTAssertEqual(home.zeroTokenRows.map(\.model.symbol), ["ZERO"], "Behind the collapsed no-balance line")
        let searched = oneList(factory, wallet: wallet, assets: [coin, zero], infos: infos, search: "zer")
        XCTAssertEqual(searched.tokenRows.map(\.model.symbol), ["ZERO"], "A search lists the zero balance itself")
        XCTAssertTrue(searched.zeroTokenRows.isEmpty)
        XCTAssertFalse(searched.searchFoundNothing)
        XCTAssertEqual(home.networkChips.map(\.id), ["all", funded.chainId], "A zero balance makes no chip")
    }

    func testOneListOffersEveryNetworkOnlyWhenTheChosenOnesFindNothing() {
        let alpha = makeChain(name: "Alpha")
        let beta = makeChain(name: "Beta")
        let one = makeChainAsset(chain: alpha, id: "one", symbol: "ONE", price: 1)
        let three = makeChainAsset(chain: beta, id: "three", symbol: "THREE", price: 1)
        let wallet = AccountGenerator.generateMetaAccount()
        let infos = balances(wallet: wallet, values: [one: 1, three: 1])
        let onAlpha = oneList(wallet: wallet, assets: [one, three], infos: infos, filter: .chain(alpha.chainId), search: "three")
        XCTAssertTrue(onAlpha.searchFoundNothing)
        XCTAssertTrue(onAlpha.canSearchAllNetworks)
        XCTAssertEqual(onAlpha.searchText, "three")
        let everywhere = oneList(wallet: wallet, assets: [one, three], infos: infos, filter: .all, search: "three")
        XCTAssertEqual(everywhere.tokenRows.map(\.model.symbol), ["THREE"])
        XCTAssertFalse(everywhere.canSearchAllNetworks)
        let found = oneList(wallet: wallet, assets: [one, three], infos: infos, filter: .chain(alpha.chainId), search: "one")
        XCTAssertFalse(found.searchFoundNothing)
        XCTAssertFalse(found.canSearchAllNetworks)
        let missing = oneList(wallet: wallet, assets: [one, three], infos: infos, filter: .all, search: "four")
        XCTAssertTrue(missing.searchFoundNothing)
        XCTAssertFalse(missing.canSearchAllNetworks, "Every network was searched already")
        XCTAssertFalse(oneList(wallet: wallet, assets: [one, three], infos: infos).searchFoundNothing)
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
        name: String? = nil,
        price: Decimal? = nil,
        isUtility: Bool = false,
        isNative: Bool = false
    ) -> ChainAsset {
        let asset = AssetModel(
            id: id,
            name: name ?? symbol,
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
}
