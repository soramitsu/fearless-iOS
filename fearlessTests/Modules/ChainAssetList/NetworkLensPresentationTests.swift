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
}
