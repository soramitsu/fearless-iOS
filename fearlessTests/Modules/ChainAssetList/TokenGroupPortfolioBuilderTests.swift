import XCTest
import SSFModels
import BigInt
@testable import fearless

final class TokenGroupPortfolioBuilderTests: XCTestCase {
    func testFactoryLensesKeepValuationIdenticalAndProvideZeroChildCells() throws {
        let assets = try usdt()
        let wallet = AccountGenerator.generateMetaAccount()
        let account = try XCTUnwrap(wallet.fetch(for: assets[0].chain.accountRequest()))
        let info = AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: 1_234_567, reserved: 1_000_000, frozen: 0, flags: 0))
        let infos: [ChainAssetKey: AccountInfo?] = [assets[0].uniqueKey(accountId: account.accountId): info]
        let factory = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        func model(_ lens: PortfolioLens) -> ChainAssetListViewModel {
            factory.buildViewModel(wallet: wallet, chainAssets: assets, locale: Locale(identifier: "en_US"), accountInfos: infos, chainsWithIssue: [], shouldRunManageAssetAnimate: false, displayType: .assetChains, chainSettings: [], networkFilter: nil, search: nil, lens: lens)
        }
        let token = model(.token), network = model(.network)
        XCTAssertEqual(token.lens, .token)
        XCTAssertEqual(network.lens, .network)
        XCTAssertEqual(token.tokenRows, network.tokenRows)
        // Remote image view models have instance identity; compare the actual
        // displayed identities and values instead of unrelated image loaders.
        XCTAssertEqual(token.networkSections.map(\.id), network.networkSections.map(\.id))
        XCTAssertEqual(token.networkSections.map(\.fiatSubtotal), network.networkSections.map(\.fiatSubtotal))
        XCTAssertEqual(token.networkSections.flatMap(\.rows).map { $0.chainAsset.assetKey }, network.networkSections.flatMap(\.rows).map { $0.chainAsset.assetKey })
        XCTAssertEqual(token.networkSections.flatMap(\.rows).map(\.balanceString), network.networkSections.flatMap(\.rows).map(\.balanceString))
        XCTAssertEqual(token.networkSections.flatMap(\.rows).map(\.totalAmountString), network.networkSections.flatMap(\.rows).map(\.totalAmountString))
        XCTAssertEqual(token.exclusions, network.exclusions)
        XCTAssertFalse(token.isWalletEmpty)
        let row = try XCTUnwrap(token.tokenRows.first)
        XCTAssertEqual(row.model.amount, Decimal(string: "2.234567"))
        XCTAssertEqual(row.amountText, "2.234567 USDT")
        XCTAssertEqual(row.model.children.count, 1)
        XCTAssertEqual(row.model.zeroChildrenCount, 2)
        XCTAssertEqual(token.tokenChildCells.count, 3)
    }

    func testFactoryExplicitShownZeroIsNotCollapsedWithAutomaticRows() throws {
        let assets = try usdt()
        let wallet = AccountGenerator.generateMetaAccount()
        let shown = assets[0]
        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: shown.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: shown.assetKey) }
        let factory = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
        let model = factory.buildViewModel(wallet: wallet, chainAssets: assets, locale: Locale(identifier: "en_US"), accountInfos: [:], chainsWithIssue: [], shouldRunManageAssetAnimate: false, displayType: .assetChains, chainSettings: [], networkFilter: nil, search: nil)
        XCTAssertTrue(model.isWalletEmpty)
        XCTAssertEqual(model.tokenRows.count, 1)
        XCTAssertEqual(model.tokenRows.first?.model.amount, 0)
        XCTAssertTrue(model.zeroTokenRows.isEmpty)
    }

    func testGroupAmountAndFiatEqualSumOfChildren() throws {
        let assets = try usdt()
        let rows = build([child(assets[0], amount: 3, fiat: 6), child(assets[1], amount: 7, fiat: 21)])
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(row.id, "group:usdt")
        XCTAssertEqual(row.amount, 10)
        XCTAssertEqual(row.fiat, 27)
        XCTAssertEqual(row.children.map(\.fiat), [21, 6])
        XCTAssertFalse(row.isSingleNetwork)
    }

    func testNoCrossMemberPricing() throws {
        let assets = try usdt()
        let row = try XCTUnwrap(build([child(assets[0], amount: 100, fiat: 100), child(assets[1], amount: 5, fiat: 999, role: .unpriced)]).first)
        XCTAssertEqual(row.amount, 105)
        XCTAssertEqual(row.fiat, 100)
        XCTAssertEqual(row.unpricedNetworkCount, 1)
        let unpriced = try XCTUnwrap(build([child(assets[0], amount: 100, role: .unpriced), child(assets[1], amount: 5, role: .unpriced)]).first)
        XCTAssertEqual(unpriced.unpricedNetworkCount, 2)
        XCTAssertEqual(unpriced.fiat, 0)
    }

    func testUnverifiedSameSymbolNeverJoinsGroup() throws {
        let assets = try usdt()
        let fake = ChainAsset(chain: assets[0].chain, asset: AssetModel(id: "impostor", name: "Tether", symbol: "USDT", precision: 6, isUtility: false, isNative: false))
        let candidates = [child(assets[0], amount: 1), child(assets[1], amount: 2), child(fake, amount: 50, role: .unverified, placement: .detected)]
        XCTAssertEqual(build(candidates).count, 1)
        XCTAssertEqual(build(candidates).first?.amount, 3)
        let explicitlyShown = build(Array(candidates.dropLast()) + [child(fake, amount: 50, role: .unverified)])
        XCTAssertEqual(explicitlyShown.count, 2)
        XCTAssertEqual(explicitlyShown.first { $0.isSingleNetwork }?.children.first?.chainAsset.assetKey, fake.assetKey)
    }

    func testDerivativeVKSMRemainsSeparateFromKSM() throws {
        let assets = try SendNetworkFixture.assets()
        let base = try XCTUnwrap(assets.first { $0.asset.symbol.lowercased() == "ksm" })
        let derivative = try XCTUnwrap(assets.first { $0.asset.symbol.lowercased() == "vksm" })
        let rows = build([child(base, amount: 1), child(derivative, amount: 1)])
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy(\.isSingleNetwork))
    }

    func testHiddenMemberExcludedAndOneActiveMemberBecomesFlat() throws {
        let assets = try usdt()
        let rows = build([child(assets[0], amount: 3, fiat: 6), child(assets[1], amount: 7, fiat: 21, role: .hidden, placement: .hidden)])
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.amount, 3)
        XCTAssertEqual(row.fiat, 6)
        XCTAssertTrue(row.isSingleNetwork)
        XCTAssertEqual(row.children.first?.networkName, assets[0].chain.name)
        XCTAssertTrue(row.id.hasPrefix("asset:"))
    }

    func testZeroMembersCountedSeparatelyAndDoNotCreateParentOnTheirOwn() throws {
        let assets = try usdt()
        let zero = child(assets[1], placement: .zeroCollapsed)
        let row = try XCTUnwrap(build([child(assets[0], amount: 3, fiat: 6), zero]).first)
        XCTAssertFalse(row.isSingleNetwork)
        XCTAssertEqual(row.children.count, 1)
        XCTAssertEqual(row.zeroChildrenCount, 1)
        XCTAssertEqual(row.zeroChildren.first?.chainAsset.assetKey, assets[1].assetKey)
        XCTAssertTrue(build([child(assets[0], placement: .zeroCollapsed), zero]).isEmpty)
        XCTAssertEqual(build([child(assets[0]), zero]).count, 1)
    }

    func testLegacyAssetKeysOrderUsesFirstMemberAndIgnoresDuplicateKeys() throws {
        let assets = try usdt()
        let other = ChainAsset(chain: assets[0].chain, asset: AssetModel(id: "other", name: "Other", symbol: "OTH", precision: 6, isUtility: false, isNative: false))
        let wallet = AccountGenerator.generateMetaAccount()
        let account = try XCTUnwrap(wallet.fetch(for: other.chain.accountRequest()))
        let key = other.uniqueKey(accountId: account.accountId)
        let orderedWallet = wallet.replacingAssetKeysOrder([key, key])
        let candidates = [child(assets[0], amount: 3, fiat: 6), child(assets[1], amount: 7, fiat: 21), child(other, amount: 1, fiat: 1)]
        let rows = TokenGroupPortfolioBuilder().build(candidates: candidates, wallet: orderedWallet)
        XCTAssertEqual(rows.map(\.symbol), ["OTH", "USDT"])
        XCTAssertEqual(build(candidates).map(\.symbol), ["USDT", "OTH"])
    }

    func testSearchByNetworkNameShowsOnlyMatchingChildren() throws {
        let assets = try usdt()
        let candidates = [child(assets[0], amount: 3, fiat: 6), child(assets[1], amount: 7, fiat: 21)]
        let rows = build(candidates, search: assets[0].chain.name.uppercased())
        XCTAssertEqual(rows.first?.id, "group:usdt")
        XCTAssertEqual(rows.first?.children.map { $0.chainAsset.assetKey }, [assets[0].assetKey])
        XCTAssertEqual(rows.first?.fiat, 6)
        XCTAssertEqual(build(candidates, search: "Tether").first?.children.count, 2)
        XCTAssertTrue(build(candidates, search: "no-match").isEmpty)
    }

    func testEmptyCatalogDegradesToExactSingleRows() throws {
        let assets = try usdt()
        let builder = TokenGroupPortfolioBuilder(catalog: CanonicalTokenGroupCatalog(data: nil, testnets: .bundled))
        let rows = builder.build(candidates: [child(assets[0], amount: 1), child(assets[1], amount: 2)], wallet: AccountGenerator.generateMetaAccount())
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy(\.isSingleNetwork))
    }

    func testDuplicateAssetCannotDoubleCount() throws {
        let assets = try usdt()
        let first = child(assets[0], amount: 3, fiat: 6)
        let row = try XCTUnwrap(build([first, first, child(assets[1], amount: 7, fiat: 21)]).first)
        XCTAssertEqual(row.amount, 10)
        XCTAssertEqual(row.fiat, 27)
        XCTAssertEqual(row.children.count, 2)
    }

    func testWalletWithoutMemberAccountCannotCreateGroup() throws {
        let assets = try usdt()
        let evm = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" })
        let substrate = try XCTUnwrap(assets.first { $0.chain.name == "Polkadot AssetHub" })
        let wallet = AccountGenerator.generateMetaAccount().replacingEthereumAddress(nil)
        let rows = TokenGroupPortfolioBuilder().build(candidates: [child(evm, placement: .zeroCollapsed), child(substrate, amount: 1)], wallet: wallet)
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows[0].isSingleNetwork)
        XCTAssertEqual(rows[0].children.first?.chainAsset.assetKey, substrate.assetKey)
    }

    func testAmountsRemainDecimalWithoutCrossPrecisionReconversion() throws {
        let assets = try usdt()
        let row = try XCTUnwrap(build([child(assets[0], amount: Decimal(string: "0.000001") ?? 0), child(assets[1], amount: Decimal(string: "1.234567") ?? 0)]).first)
        XCTAssertEqual(row.amount, Decimal(string: "1.234568"))
    }

    private func usdt() throws -> [ChainAsset] {
        let assets = try SendNetworkFixture.assets().filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
        XCTAssertEqual(assets.count, 3)
        return assets.sorted { $0.chain.name < $1.chain.name }
    }

    private func child(_ asset: ChainAsset, amount: Decimal = 0, fiat: Decimal = 0, role: PortfolioValueRole = .counted, placement: PortfolioPlacement = .visible) -> TokenGroupChildModel {
        TokenGroupChildModel(chainAsset: asset, value: PortfolioHoldingValue(role: role, amount: amount, transferable: amount, fiat: fiat, dayChange: 0), placement: placement)
    }

    private func build(_ candidates: [TokenGroupChildModel], search: String? = nil) -> [TokenGroupRowModel] {
        TokenGroupPortfolioBuilder().build(candidates: candidates, wallet: AccountGenerator.generateMetaAccount(), search: search)
    }
}
