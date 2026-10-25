import XCTest
import SSFModels
import BigInt
@testable import fearless

final class ManageAssetsGroupingTests: XCTestCase {
    func testSectionsUseApprovedIdentityAndKeepHiddenMembersReachable() throws {
        let assets = try usdt()
        let wallet = AccountGenerator.generateMetaAccount()
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: assets[0].assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: assets[0].assetKey) }
        let model = build(assets, wallet: wallet)
        let section = try XCTUnwrap(model.list.first)
        XCTAssertEqual(model.list.count, 1)
        XCTAssertEqual(section.id, "group:usdt")
        XCTAssertTrue(section.hasView)
        XCTAssertFalse(section.isExpanded)
        XCTAssertEqual(Set(section.cells.map { $0.chainAsset.assetKey }), Set(assets.map(\.assetKey)))
        XCTAssertEqual(section.assetName, "USDT")
        XCTAssertTrue(section.cells.allSatisfy(\.hasGroup))
        XCTAssertEqual(section.cells.first { $0.chainAsset.assetKey == assets[0].assetKey }?.preference, .hidden)
    }

    func testUngroupedSameSymbolAndOneActiveMemberStayFlat() throws {
        let approved = try usdt()
        let impostor = ChainAsset(chain: approved[0].chain, asset: AssetModel(id: "impostor", name: "Tether", symbol: "USDT", precision: 6, isUtility: false, isNative: false))
        let flat = build([approved[0], impostor])
        XCTAssertEqual(flat.list.count, 2)
        XCTAssertTrue(flat.list.allSatisfy { !$0.hasView && $0.cells.count == 1 })
        let wallet = AccountGenerator.generateMetaAccount().replacingEthereumAddress(nil)
        let all = build(approved, wallet: wallet)
        XCTAssertFalse(all.list.contains { $0.id == "group:usdt" })
    }

    func testDisabledUnusedAndDuplicateAssetsDoNotBecomeMembers() throws {
        let assets = try usdt()
        let wallet = AccountGenerator.generateMetaAccount().replacingUnusedChainIds([assets[1].chain.chainId, assets[2].chain.chainId])
        let model = build(assets + [assets[0]], wallet: wallet)
        XCTAssertEqual(model.list.flatMap(\.cells).map { $0.chainAsset.assetKey }, [assets[0].assetKey])
        XCTAssertFalse(try XCTUnwrap(model.list.first).hasView)
        let disabled = asset(name: "Disabled", disabled: true)
        XCTAssertTrue(build([disabled]).list.isEmpty)
    }

    func testTestnetsAndUnverifiedAreSeparateCollapsedTrailingSections() throws {
        let standard = asset(name: "Mainnet")
        let testnet = asset(name: "Testnet", options: [.testnet])
        let unknown = asset(name: "Unknown")
        AssetTrustResolver.markUnverified(unknown)
        let model = build([testnet, unknown, standard])
        XCTAssertEqual(model.list.map(\.id), ["asset:" + standard.identifier, "unverified", "testnets"])
        XCTAssertTrue(model.list.suffix(2).allSatisfy { $0.hasView && !$0.isExpanded && $0.totalFiatBalance == 0 })
        XCTAssertEqual(model.list[1].assetName, "Unverified")
        XCTAssertTrue(model.list[1].assetCount?.contains("unsafe") == true)
        XCTAssertEqual(model.list[2].assetName, "Testnets")
    }

    func testSwitchUsesEffectiveVisibilityAndKeepsPreferenceCaption() throws {
        let row = asset(name: "Zero")
        let wallet = AccountGenerator.generateMetaAccount()
        let account = try XCTUnwrap(wallet.fetch(for: row.chain.accountRequest()))
        let zero = AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: 0, reserved: 0, frozen: 0, flags: 0))
        let automatic = try XCTUnwrap(build([row], wallet: wallet, infos: [row.uniqueKey(accountId: account.accountId): zero]).list.first?.cells.first)
        XCTAssertTrue(automatic.hidden)
        XCTAssertEqual(automatic.preference, .auto)
        XCTAssertEqual(automatic.preferenceCaption, "Auto · no balance")
        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: row.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: row.assetKey) }
        let shown = try XCTUnwrap(build([row], wallet: wallet).list.first?.cells.first)
        XCTAssertFalse(shown.hidden)
        XCTAssertEqual(shown.preferenceCaption, "Shown")
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: row.assetKey)
        let hidden = try XCTUnwrap(build([row], wallet: wallet).list.first?.cells.first)
        XCTAssertTrue(hidden.hidden)
        XCTAssertEqual(hidden.preferenceCaption, "Hidden")
    }

    func testUnknownBalanceDoesNotClaimThereIsNoBalance() throws {
        let row = asset(name: "Not scanned")
        let cell = try XCTUnwrap(build([row]).list.first?.cells.first)
        XCTAssertEqual(cell.preferenceCaption, "Auto")
        XCTAssertTrue(cell.hidden)
    }

    func testFundedAutomaticUsesTotalIncludingReservedAtExactPrecision() throws {
        let row = asset(name: "Reserved", precision: 6)
        let wallet = AccountGenerator.generateMetaAccount()
        let account = try XCTUnwrap(wallet.fetch(for: row.chain.accountRequest()))
        let info = AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: 1_234_567, reserved: 1_000_000, frozen: 1_234_567, flags: 0))
        let model = build([row], wallet: wallet, infos: [row.uniqueKey(accountId: account.accountId): info])
        let cell = try XCTUnwrap(model.list.first?.cells.first)
        XCTAssertFalse(cell.hidden)
        XCTAssertEqual(cell.amount, Decimal(string: "2.234567"))
        XCTAssertEqual(cell.balance.amount, "2.234567")
        XCTAssertEqual(cell.preferenceCaption, "Auto")
        XCTAssertNil(cell.balance.price, "Missing prices are not a fictional fiat zero")
    }

    func testUpdateRecomputesPreferencesWithoutDoubleToggleAndPreservesExpansion() throws {
        let assets = try usdt(), wallet = AccountGenerator.generateMetaAccount()
        let factory = factory()
        let initial = build(assets, wallet: wallet)
        let expanded = factory.toggle(viewModel: initial, on: 0)
        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: assets[0].assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: assets[0].assetKey) }
        func update(_ model: AssetManagementViewModel) -> AssetManagementViewModel {
            factory.update(viewModel: model, at: IndexPath(row: 0, section: 999), pendingAccountInfoChainAssets: [assets[0].chainAssetId], accountInfos: [:], locale: Locale(identifier: "en_US"), wallet: wallet)
        }
        let saved = update(expanded), refreshed = update(saved)
        for model in [saved, refreshed] {
            XCTAssertTrue(try XCTUnwrap(model.list.first).isExpanded)
            let cell = try XCTUnwrap(model.list.flatMap(\.cells).first { $0.chainAsset.assetKey == assets[0].assetKey })
            XCTAssertFalse(cell.hidden)
            XCTAssertEqual(cell.preference, .shown)
            XCTAssertTrue(cell.isLoadingBalance)
        }
        XCTAssertEqual(factory.toggle(viewModel: initial, on: 99).list.map(\.isExpanded), initial.list.map(\.isExpanded))
        XCTAssertFalse(try XCTUnwrap(factory.toggle(viewModel: build([assets[0]]), on: 0).list.first).isExpanded)
    }

    func testRankThenNameSortingIsStableAndSearchKeepsExactRows() {
        let zebra = asset(name: "Zebra", rank: 1), alpha = asset(name: "Alpha", rank: 1), ranked = asset(name: "Ranked", rank: 0)
        XCTAssertEqual(build([zebra, alpha, ranked]).list.map(\.assetName), ["RANKED", "ALPHA", "ZEBRA"])
        let model = factory().buildViewModel(chainAssets: [zebra, alpha, ranked], accountInfos: [:], wallet: AccountGenerator.generateMetaAccount(), locale: Locale(identifier: "en_US"), filter: nil, search: "alph", pendingAccountInfoChainAssets: [])
        XCTAssertEqual(model.list.flatMap(\.cells).map { $0.chainAsset.assetKey }, [alpha.assetKey])
    }

    func testGroupStateAndMembershipRemainCompleteAfterNetworkAndVisibilityFiltering() throws {
        let assets = try usdt(), wallet = AccountGenerator.generateMetaAccount()
        AssetVisibilityPreferenceStore.setPreference(.shown, walletId: wallet.metaId, assetKey: assets[0].assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: assets[0].assetKey) }
        let model = factory().buildViewModel(chainAssets: assets, accountInfos: [:], wallet: wallet, locale: Locale(identifier: "en"), filter: .chain(assets[0].chain.chainId), search: nil, pendingAccountInfoChainAssets: [])
        let section = try XCTUnwrap(model.list.first)
        XCTAssertEqual(section.cells.count, 1)
        XCTAssertEqual(Set(section.visibilityMembers.map(\.assetKey)), Set(assets.map(\.assetKey)))
        XCTAssertEqual(section.groupVisibility, .mixed)
        XCTAssertEqual(model.filtered(by: .shown).list.first?.visibilityMembers.count, assets.count)
        XCTAssertEqual(model.filtered(by: .shown).list.first?.groupVisibility, .mixed)
        XCTAssertTrue(build(assets, wallet: AccountGenerator.generateMetaAccount()).list.allSatisfy { $0.groupVisibility == .off })
    }

    func testVisibilityFiltersKeepAutomaticDistinctFromExplicitHiddenAndRetainExactRows() throws {
        let assets = try usdt(), wallet = AccountGenerator.generateMetaAccount()
        let model = build(assets, wallet: wallet)
        var section = try XCTUnwrap(model.list.first)
        XCTAssertGreaterThanOrEqual(section.cells.count, 2)
        section.cells[0].preference = .auto
        section.cells[0].hidden = false
        section.cells[1].preference = .hidden
        section.cells[1].hidden = true
        section.cells = Array(section.cells.prefix(2))
        var fixture = model
        fixture.list = [section]
        XCTAssertEqual(fixture.filtered(by: .all).list[0].cells.count, 2)
        XCTAssertEqual(fixture.filtered(by: .shown).dispayedChainAssets.map(\.assetKey), [section.cells[0].chainAsset.assetKey])
        XCTAssertEqual(fixture.filtered(by: .auto).dispayedChainAssets.map(\.assetKey), [section.cells[0].chainAsset.assetKey])
        XCTAssertEqual(fixture.filtered(by: .hidden).dispayedChainAssets.map(\.assetKey), [section.cells[1].chainAsset.assetKey])
        section.cells[0].hidden = true
        fixture.list = [section]
        XCTAssertTrue(fixture.filtered(by: .shown).list.isEmpty)
        XCTAssertEqual(fixture.filtered(by: .hidden).list[0].cells.count, 1, "Automatic zero rows are not explicit hides")
        XCTAssertEqual(fixture.filtered(by: .hidden).visibilityFilter, .hidden)
        XCTAssertEqual(fixture.list[0].cells.count, 2, "Filtering must not mutate the source model")
    }

    func testInvalidCatalogLeavesExactRowsAndEveryShippedLocaleHasCaptions() throws {
        let assets = try usdt()
        let f = AssetManagementViewModelFactoryDefault(assetBalanceFormatterFactory: AssetBalanceFormatterFactory(), catalog: CanonicalTokenGroupCatalog(data: nil, testnets: .bundled))
        let model = f.buildViewModel(chainAssets: assets, accountInfos: [:], wallet: AccountGenerator.generateMetaAccount(), locale: Locale(identifier: "en_US"), filter: nil, search: nil, pendingAccountInfoChainAssets: [])
        XCTAssertEqual(model.list.count, assets.count)
        XCTAssertTrue(model.list.allSatisfy { !$0.hasView })
        for locale in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for suffix in ["mixed", "show_group", "hide_group", "reset_auto", "all", "auto", "auto_zero", "shown", "hidden", "testnets", "testnets_caption", "unverified", "unverified_caption"] {
                let key = "manage_assets." + suffix
                XCTAssertNotEqual(PortfolioStrings.text(key, locale: Locale(identifier: locale)), key)
            }
        }
    }

    private func usdt() throws -> [ChainAsset] {
        let assets = try SendNetworkFixture.assets().filter { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" }
        XCTAssertEqual(assets.count, 3)
        return assets
    }

    private func factory() -> AssetManagementViewModelFactoryDefault {
        AssetManagementViewModelFactoryDefault(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
    }

    private func build(_ assets: [ChainAsset], wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(), infos: [ChainAssetKey: AccountInfo?] = [:]) -> AssetManagementViewModel {
        factory().buildViewModel(chainAssets: assets, accountInfos: infos, wallet: wallet, locale: Locale(identifier: "en_US"), filter: nil, search: nil, pendingAccountInfoChainAssets: [])
    }

    private func asset(name: String, precision: UInt16 = 0, rank: UInt16? = nil, disabled: Bool = false, options: [ChainOptions]? = nil) -> ChainAsset {
        let chain = ChainModel(rank: rank, disabled: disabled, chainId: UUID().uuidString, parentId: nil, paraId: nil, name: name, xcm: nil, nodes: [], addressPrefix: 42, types: nil, icon: nil, options: options, externalApi: nil, selectedNode: nil, customNodes: nil, iosMinAppVersion: nil, identityChain: nil)
        let asset = AssetModel(id: "0", name: name, symbol: name, precision: precision, isUtility: false, isNative: false)
        chain.assets.insert(asset)
        return ChainAsset(chain: chain, asset: asset)
    }
}
