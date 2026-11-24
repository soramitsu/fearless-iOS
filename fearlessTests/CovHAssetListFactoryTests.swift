import XCTest
import SSFModels
import BigInt
@testable import fearless

final class CovHAssetListFactoryTests: XCTestCase {
    private let factory = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
    private let wallet = AccountGenerator.generateMetaAccount()

    private func balances(_ assets: [ChainAsset], amount: UInt64 = 1000) -> [ChainAssetKey: AccountInfo?] {
        Dictionary(uniqueKeysWithValues: assets.compactMap { asset -> (ChainAssetKey, AccountInfo?)? in
            guard let accountId = wallet.fetch(for: asset.chain.accountRequest())?.accountId else { return nil }
            return (asset.uniqueKey(accountId: accountId), AccountInfo(ethBalance: BigUInt(amount)))
        })
    }

    private func build(
        _ assets: [ChainAsset],
        issues: [ChainIssue] = [],
        filter: NetworkManagmentFilter?,
        displayType: AssetListDisplayType = .chain,
        accountInfos: [ChainAssetKey: AccountInfo?]? = nil
    ) -> ChainAssetListViewModel {
        factory.buildViewModel(
            wallet: wallet,
            chainAssets: assets,
            locale: Locale(identifier: "en"),
            accountInfos: accountInfos ?? balances(assets),
            chainsWithIssue: issues,
            shouldRunManageAssetAnimate: false,
            displayType: displayType,
            chainSettings: [],
            networkFilter: filter,
            search: nil,
            lens: .network
        )
    }

    func testSingleNetworkWithANetworkIssueAsksToRetry() {
        let asset = CovHAssetListFixture.chainAsset()
        let model = build([asset], issues: [.network(chains: [asset.chain])], filter: .chain(asset.chain.chainId))

        guard case let .chainHasNetworkIssue(chain) = model.displayState else {
            return XCTFail("Expected the network issue state, got \(model.displayState)")
        }
        XCTAssertEqual(chain.chainId, asset.chain.chainId)
    }

    func testSingleNetworkWithoutAnAccountAsksToAddOne() {
        let asset = CovHAssetListFixture.chainAsset()
        let model = build([asset], issues: [.missingAccount(chains: [asset.chain])], filter: .chain(asset.chain.chainId))

        guard case let .chainHasAccountIssue(chain) = model.displayState else {
            return XCTFail("Expected the account issue state, got \(model.displayState)")
        }
        XCTAssertEqual(chain.chainId, asset.chain.chainId)
    }

    func testSkippedMissingAccountIsNotAnIssue() {
        let asset = CovHAssetListFixture.chainAsset()
        let model = factory.buildViewModel(
            wallet: wallet.replacingUnusedChainIds([asset.chain.chainId]),
            chainAssets: [asset],
            locale: Locale(identifier: "en"),
            accountInfos: balances([asset]),
            chainsWithIssue: [.missingAccount(chains: [asset.chain])],
            shouldRunManageAssetAnimate: false,
            displayType: .chain,
            chainSettings: [],
            networkFilter: .chain(asset.chain.chainId),
            search: nil,
            lens: .network
        )

        guard case let .defaultList(cells, _) = model.displayState else {
            return XCTFail("Expected the plain list, got \(model.displayState)")
        }
        XCTAssertEqual(cells.map(\.chainAsset.assetKey), [asset.assetKey])
    }

    func testSeveralAssetsOnTheSelectedNetworkShowTheList() {
        let chain = CovHAssetListFixture.chain()
        let first = CovHAssetListFixture.chainAsset(chain: chain, id: "first", symbol: "FST")
        let second = CovHAssetListFixture.chainAsset(chain: chain, id: "second", symbol: "SND")
        let model = build([first, second], filter: .chain(chain.chainId))

        guard case let .defaultList(cells, animate) = model.displayState else {
            return XCTFail("Expected the plain list, got \(model.displayState)")
        }
        XCTAssertEqual(Set(cells.map(\.chainAsset.assetKey)), [first.assetKey, second.assetKey])
        XCTAssertFalse(animate)
        XCTAssertEqual(model.displayState.rows.count, 2)
        XCTAssertFalse(model.displayState.isSearch)
    }

    func testEveryAssetHiddenOnTheSelectedNetworkSaysSo() {
        let asset = CovHAssetListFixture.chainAsset(id: "hidden-\(UUID().uuidString)")
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: asset.assetKey)
        defer { AssetVisibilityPreferenceStore.setPreference(.auto, walletId: wallet.metaId, assetKey: asset.assetKey) }

        let model = build([asset], filter: .chain(asset.chain.chainId))

        guard case .allIsHidden = model.displayState else {
            return XCTFail("Expected the all-hidden state, got \(model.displayState)")
        }
        XCTAssertTrue(model.displayState.rows.isEmpty)
    }

    func testSolanaNetworkSectionNamesItsEcosystem() {
        let chain = CovHAssetListFixture.chain(id: "solana:cov-h-\(UUID().uuidString.prefix(8))", name: "Cov Solana")
        let asset = CovHAssetListFixture.chainAsset(chain: chain, id: "sol", symbol: "SOL")

        let model = build([asset], filter: .all, displayType: .assetChains)

        XCTAssertTrue(model.networkSections.contains { $0.ecosystemName == "Solana" }, "\(model.networkSections.map(\.ecosystemName))")
    }

    func testHiddenFundsNoticeCountsSeveralAssets() throws {
        let defaults = CovHAssetListFixture.defaults()
        let walletId = UUID().uuidString
        let keys = [
            AssetKey(ecosystem: "substrate", chainId: "cov-h-a", assetId: "a"),
            AssetKey(ecosystem: "substrate", chainId: "cov-h-b", assetId: "b")
        ]
        defaults.set(
            keys.map(AssetVisibilityPreferenceStore.storageIdentifier(for:)),
            forKey: "asset.presentation.hidden_in_previous_version:\(walletId)"
        )
        var exclusions = PortfolioExclusions()
        exclusions.hiddenFundedAssetKeys = keys

        let notice = try XCTUnwrap(ChainAssetListViewModelFactory.hiddenFundsNotice(for: exclusions, walletId: walletId, userDefaults: defaults))
        XCTAssertEqual(notice.assetKeys, keys)
        XCTAssertTrue(notice.title.contains("2"))

        AssetVisibilityPreferenceStore.markHiddenFundsReviewed([keys[0]], walletId: walletId, userDefaults: defaults)
        let single = try XCTUnwrap(ChainAssetListViewModelFactory.hiddenFundsNotice(for: exclusions, walletId: walletId, userDefaults: defaults))
        XCTAssertEqual(single.assetKeys, [keys[1]])
        XCTAssertNotEqual(single.title, notice.title)

        AssetVisibilityPreferenceStore.markHiddenFundsReviewed([keys[1]], walletId: walletId, userDefaults: defaults)
        XCTAssertNil(ChainAssetListViewModelFactory.hiddenFundsNotice(for: exclusions, walletId: walletId, userDefaults: defaults))
    }

    func testChainAssetEcosystemAndParent() {
        let evm = CovHAssetListFixture.chainAsset(chain: CovHAssetListFixture.chain(options: [.ethereum]))
        let polkadot = CovHAssetListFixture.chainAsset(chain: CovHAssetListFixture.chain(id: Chain.polkadot.genesisHash))
        let other = CovHAssetListFixture.chainAsset()

        let evmEcosystem: fearless.ChainEcosystem = evm.defineEcosystem()
        let polkadotEcosystem: fearless.ChainEcosystem = polkadot.defineEcosystem()
        let otherEcosystem: fearless.ChainEcosystem = other.defineEcosystem()
        XCTAssertEqual(evmEcosystem, .ethereum)
        XCTAssertEqual(polkadotEcosystem, .polkadot)
        XCTAssertEqual(otherEcosystem, .kusama)
        XCTAssertTrue(other.isParentChain())
    }

    func testCellViewModelsCompareAndHashByContent() {
        let asset = CovHAssetListFixture.chainAsset()
        let first = CovHAssetListPresenterContext.cell(for: asset)
        let same = CovHAssetListPresenterContext.cell(for: asset)
        let other = CovHAssetListPresenterContext.cell(for: asset, balance: "2")

        XCTAssertEqual(first, same)
        XCTAssertNotEqual(first, other)
        XCTAssertEqual(Set([first, same, other]).count, 2)
        XCTAssertEqual(first.hashValue, same.hashValue)
    }

    func testListStateRows() {
        let cell = CovHAssetListPresenterContext.cell(for: CovHAssetListFixture.chainAsset())
        let chain = CovHAssetListFixture.chain()

        XCTAssertEqual(AssetListState.search(cells: [cell]).rows, [cell])
        XCTAssertTrue(AssetListState.search(cells: []).isSearch)
        XCTAssertEqual(AssetListState.defaultList(cells: [cell], withAnimate: true).rows, [cell])
        XCTAssertTrue(AssetListState.allIsHidden.rows.isEmpty)
        XCTAssertTrue(AssetListState.chainHasNetworkIssue(chain: chain).rows.isEmpty)
        XCTAssertFalse(AssetListState.chainHasAccountIssue(chain: chain).isSearch)
    }
}
