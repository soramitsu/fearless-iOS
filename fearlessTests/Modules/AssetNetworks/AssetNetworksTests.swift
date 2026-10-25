import XCTest
import SSFModels
@testable import fearless

final class AssetNetworksTests: XCTestCase {
    func testNetworksListUsesCanonicalGroupNotSymbol() throws {
        let assets = try SendNetworkFixture.assets()
        let source = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        let impostor = ChainAsset(chain: source.chain, asset: AssetModel(id: "impostor", name: "Tether", symbol: "xcUSDT", precision: 6, isUtility: false, isNative: false))
        let actual = AssetNetworksInteractor.availableAssets(for: source, among: assets + [impostor], wallet: AccountGenerator.generateMetaAccount())
        XCTAssertEqual(actual.count, 3)
        XCTAssertTrue(actual.allSatisfy { CanonicalTokenGroupCatalog.bundled.group(for: $0)?.id == "usdt" })
        XCTAssertFalse(actual.contains { $0.assetKey == impostor.assetKey })
    }

    func testMissingCatalogKeepsOnlyExactAssetAndDeduplicates() throws {
        let assets = try SendNetworkFixture.assets()
        let source = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        let empty = CanonicalTokenGroupCatalog(data: nil, testnets: .bundled)
        let actual = AssetNetworksInteractor.availableAssets(for: source, among: assets + [source], wallet: AccountGenerator.generateMetaAccount(), catalog: empty)
        XCTAssertEqual(actual.map(\.assetKey), [source.assetKey])
    }

    func testHiddenAndAccountlessMembersAreUnavailableButAutoZerosRemain() throws {
        let assets = try SendNetworkFixture.assets()
        let source = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        let wallet = AccountGenerator.generateMetaAccount().replacingEthereumAddress(nil)
        let suite = "asset-networks-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let available = AssetNetworksInteractor.availableAssets(for: source, among: assets, wallet: wallet, userDefaults: defaults)
        XCTAssertEqual(available.count, 1)
        XCTAssertFalse(available.contains { $0.assetKey == source.assetKey })
        let hidden = try XCTUnwrap(available.first)
        AssetVisibilityPreferenceStore.setPreference(.hidden, walletId: wallet.metaId, assetKey: hidden.assetKey, userDefaults: defaults)
        XCTAssertEqual(AssetNetworksInteractor.availableAssets(for: source, among: assets, wallet: wallet, userDefaults: defaults).count, 0)
    }

    func testDisabledNetworkDoesNotAppear() throws {
        let assets = try SendNetworkFixture.assets()
        let source = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        let wallet = AccountGenerator.generateMetaAccount().replacingUnusedChainIds([source.chain.chainId])
        let available = AssetNetworksInteractor.availableAssets(for: source, among: assets, wallet: wallet)
        XCTAssertEqual(available.count, 2)
        XCTAssertFalse(available.contains { $0.assetKey == source.assetKey })
    }
}
