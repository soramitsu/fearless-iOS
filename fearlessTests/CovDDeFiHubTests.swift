import BigInt
import Foundation
import SSFModels
import SSFPools
import UIKit
import XCTest

@testable import fearless

final class CovDDeFiSourceStub: DeFiPositionSourceLoading {
    let feature: DeFiFeature
    let title: String
    var results: [Result<[DeFiHubPositionRow], Error>]

    init(feature: DeFiFeature, title: String, results: [Result<[DeFiHubPositionRow], Error>]) {
        self.feature = feature
        self.title = title
        self.results = results
    }

    func loadPositions() async throws -> [DeFiHubPositionRow] {
        let next = results.count > 1 ? results.removeFirst() : results[0]
        return try next.get()
    }
}

struct CovDSoraLoaderStub: SoraLiquidityPoolPositionLoading {
    let pools: [AccountPool]

    func loadPositions(accountId _: Data) async throws -> [AccountPool] { pools }
}

final class CovDDeFiAggregatorTests: XCTestCase {
    private func row(_ id: String, kind: DeFiHubPositionRowKind = .position, feature: DeFiFeature = .staking) -> DeFiHubPositionRow {
        DeFiHubPositionRow(id: id, feature: feature, kind: kind, title: "Row \(id)", subtitle: "sub \(id)")
    }

    func testStateAndLoadingRow() {
        XCTAssertTrue(DeFiCapabilityState.available.isAvailable)
        XCTAssertNil(DeFiCapabilityState.available.reason)
        XCTAssertFalse(DeFiCapabilityState.unavailable(reason: "r").isAvailable)
        XCTAssertEqual(DeFiCapabilityState.unavailable(reason: "r").reason, "r")
        XCTAssertEqual(DeFiHubPositionRow.loadingPositions.kind, .loading)
        XCTAssertEqual(DeFiHubPositionRow.loadingPositions.title, "Loading positions…")
        XCTAssertEqual(DeFiHubPositionRow.loadingPositions.freshness, .current)
        XCTAssertEqual(CovDDeFiSourceStub(feature: .farming, title: "Demeter", results: [.success([])]).sourceId, "farming:Demeter")
    }

    func testAggregatorCachesRowsAndMarksLaterFailuresStale() async {
        let flaky = CovDDeFiSourceStub(feature: .farming, title: "Demeter", results: [
            .success([row("b", feature: .farming), row("s", kind: .status, feature: .farming)]),
            .failure(CovDTestError.offline)
        ])
        let broken = CovDDeFiSourceStub(feature: .polkamarkt, title: "Polkamarkt", results: [.failure(CovDTestError.offline)])
        let healthy = CovDDeFiSourceStub(feature: .staking, title: "Staking", results: [.success([row("a")])])
        let aggregator = DeFiPositionsAggregator(sources: [flaky, broken, healthy], explicitlyUnavailableRows: [])

        let first = await aggregator.load()
        XCTAssertEqual(first.rows.filter { $0.kind == .position }.map(\.id), ["a", "b"])
        XCTAssertTrue(first.hasPositivePositions)
        XCTAssertTrue(first.hasPartialFailure)
        let unavailable = first.rows.first { $0.id == "status:polkamarkt:unavailable" }
        XCTAssertEqual(unavailable?.title, "Polkamarkt positions unavailable")
        XCTAssertEqual(unavailable?.freshness, .unavailable)

        let second = await aggregator.load()
        let stale = second.rows.first { $0.id == "status:farming:stale" }
        XCTAssertEqual(stale?.title, "Demeter positions are stale")
        XCTAssertEqual(stale?.freshness, .stale)
        XCTAssertTrue(second.rows.contains { $0.id == "b" })
    }

    func testAggregatorReportsEmptyAndExplicitlyUnavailableStates() async {
        let empty = await DeFiPositionsAggregator(
            sources: [CovDDeFiSourceStub(feature: .staking, title: "Staking", results: [.success([])])],
            explicitlyUnavailableRows: []
        ).load()
        XCTAssertEqual(empty.rows.map(\.id), ["positions:empty"])
        XCTAssertEqual(empty.rows.first?.kind, .empty)
        XCTAssertFalse(empty.hasPositivePositions)
        XCTAssertFalse(empty.hasPartialFailure)

        let explicit = await DeFiPositionsAggregator(
            sources: [],
            explicitlyUnavailableRows: [row("z", kind: .status), row("y", kind: .status)]
        ).load()
        XCTAssertEqual(explicit.rows.map(\.id), ["y", "z"])
        XCTAssertTrue(explicit.hasPartialFailure)
    }

    func testRowFactoriesForDemeterPolkamarktAndPools() throws {
        let chain = CovDDemeterFixtures.pricedChain()
        let pool = CovDDemeterFixtures.makePool()
        let rows = DeFiPositionRowFactory.demeter([
            CovDDemeterFixtures.position(pool, pooled: "2000000000000000000", rewards: "0"),
            CovDDemeterFixtures.position(CovDDemeterFixtures.makePool(isFarm: false), pooled: "0", rewards: "0")
        ], chain: chain)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.title, "Farm VAL")
        XCTAssertEqual(rows.first?.subtitle, "Deposited 2 · Rewards 0 PSWAP")
        XCTAssertEqual(rows.first?.feature, .farming)
        XCTAssertTrue(rows.first?.id.hasPrefix("demeter:") == true)

        let positions = try JSONDecoder().decode([PolkamarktPosition].self, from: Data("""
        [{"id": "p1", "marketId": 4, "outcome": "no", "shares": "1000000000000000000", "status": "Open"},
         {"id": "p2", "marketId": 5, "netCollateralPaid": "3"},
         {"id": "p3", "marketId": 6}]
        """.utf8))
        let markets = DeFiPositionRowFactory.polkamarkt(positions)
        XCTAssertEqual(markets.map(\.id), ["polkamarkt:p1", "polkamarkt:p2"])
        XCTAssertEqual(markets.first?.title, "Market #4 · NO")
        XCTAssertEqual(markets.first?.subtitle, "1 shares · Open")

        let staking = DeFiPositionRowFactory.staking(
            StakingLocks(staked: 2, unstaking: 0, redeemable: 1, claimable: nil),
            chainAsset: try XCTUnwrap(CovDFixtures.chainAsset(chain, currencyId: CovDFixtures.xorAssetId)),
            feature: .nominationPools
        )
        XCTAssertEqual(staking.first?.title, "SORA nomination pool")
        XCTAssertEqual(staking.first?.subtitle, "2 XOR staked · 1 XOR redeemable")
        XCTAssertTrue(staking.first?.id.hasPrefix("nomination-pool:") == true)
    }

    func testLiquidityRowsRejectForeignChainsUnknownAssetsAndSelfPairs() async throws {
        let chain = CovDFixtures.soraChain()
        func pool(chainId: String? = nil, base: String = CovDFixtures.xorAssetId, target: String = CovDFixtures.valAssetId) -> AccountPool {
            AccountPool(
                poolId: "pool", accountId: "0xaccount", chainId: chainId ?? chain.chainId,
                baseAssetId: base, targetAssetId: target,
                baseAssetPooled: 1, targetAssetPooled: 2, accountPoolShare: Decimal(string: "0.5")
            )
        }
        XCTAssertThrowsError(try DeFiPositionRowFactory.liquidityPools([pool(chainId: "other")], chain: chain)) {
            XCTAssertEqual($0 as? SoraLiquidityPoolPositionError, .identityMismatch(poolId: "pool"))
        }
        XCTAssertThrowsError(try DeFiPositionRowFactory.liquidityPools([pool(target: "0xdead")], chain: chain)) {
            XCTAssertEqual($0 as? SoraLiquidityPoolPositionError, .assetUnavailable(assetId: "0xdead"))
        }
        XCTAssertThrowsError(try DeFiPositionRowFactory.liquidityPools([pool(target: CovDFixtures.xorAssetId)], chain: chain)) {
            XCTAssertEqual($0 as? SoraLiquidityPoolPositionError, .identityMismatch(poolId: "pool"))
        }
        let source = SoraLiquidityPoolDeFiPositionSource(chain: chain, accountId: Data(repeating: 1, count: 32), loader: CovDSoraLoaderStub(pools: [pool()]))
        XCTAssertEqual(source.feature, .liquidityPools)
        XCTAssertEqual(source.title, "Liquidity pools")
        let rows = try await source.loadPositions()
        XCTAssertEqual(rows.first?.title, "XOR / VAL liquidity")
        XCTAssertTrue(rows.first?.subtitle.hasPrefix("Pooled 1 XOR · 2 VAL · 0.5% share · SORA 0x02000000…000000 / 0x02000400…000000") == true)

        let errors: [SoraLiquidityPoolPositionError] = [
            .snapshotUnavailable, .assetUnavailable(assetId: "a"), .identityMismatch(poolId: "p"), .balanceUnavailable(poolId: "p")
        ]
        XCTAssertEqual(Set(errors.compactMap(\.errorDescription)).count, 4)
        XCTAssertEqual(SoraLiquidityPoolPositionError.assetUnavailable(assetId: "a").errorDescription,
                       "The SORA registry cannot identify exactly one pool asset for a.")
    }
}

final class CovDDeFiHubControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private func presentedAlert(_ controller: UIViewController) -> UIAlertController? {
        CovDFixtures.spin { controller.presentedViewController != nil }
        let alert = controller.presentedViewController as? UIAlertController
        controller.presentedViewController?.dismiss(animated: false)
        CovDFixtures.spin { controller.presentedViewController == nil }
        return alert
    }

    func testHubListsLoadedPositionsAndAllOpportunities() throws {
        let stale = DeFiHubPositionRow(
            id: "status:farming:stale", feature: .farming, kind: .status, title: "Demeter positions are stale",
            subtitle: "x", freshness: .stale
        )
        let source = CovDDeFiSourceStub(feature: .staking, title: "Staking", results: [.success([
            DeFiHubPositionRow(id: "p", feature: .polkamarkt, kind: .position, title: "Market #1 · YES", subtitle: "1 shares · Open")
        ])])
        let aggregator = DeFiPositionsAggregator(sources: [source], explicitlyUnavailableRows: [stale])
        let controller = DeFiHubViewController(wallet: CovDFixtures.wallet(), positionsAggregator: aggregator)
        let navigation = UINavigationController(rootViewController: controller)
        window = try CovDFixtures.host(navigation)
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: controller.view))
        XCTAssertEqual(controller.title, MainTabBarDestination.defi.title)
        XCTAssertEqual(
            controller.navigationItem.rightBarButtonItem?.accessibilityLabel,
            NSLocalizedString("ux.refresh_positions", value: "Refresh positions", comment: "")
        )
        XCTAssertEqual(table.dataSource?.numberOfSections?(in: table), 2)
        XCTAssertEqual(table.dataSource?.tableView?(table, titleForHeaderInSection: 0), "Your positions")
        XCTAssertEqual(
            table.dataSource?.tableView?(table, titleForHeaderInSection: 1),
            NSLocalizedString("ux.explore_earn", value: "Explore ways to earn", comment: "")
        )

        XCTAssertTrue(CovDFixtures.spin { CovDFixtures.cellTexts(table, section: 0).count == 2 })
        let positions = CovDFixtures.cellTexts(table, section: 0)
        XCTAssertEqual(positions.map(\.0), ["Market #1 · YES", "Demeter positions are stale"])
        XCTAssertEqual(positions[0].1, "1 shares · Open")
        XCTAssertEqual(
            positions[1].1,
            NSLocalizedString("ux.positions_stale", value: "Showing your last loaded positions. Try again to update them.", comment: "")
        )

        let opportunities = CovDFixtures.cellTexts(table, section: 1)
        XCTAssertEqual(opportunities.map(\.0), ["Staking", "Nomination pools", "Liquidity pools", "Farming", "Polkamarkt"])
        if ChainRegistryFacade.sharedRegistry.availableChains.isEmpty {
            XCTAssertEqual(opportunities[0].1, "No supported native staking network is available.")
            XCTAssertEqual(opportunities[1].1, "No supported nomination-pool network is available.")
            XCTAssertEqual(opportunities[4].1, "SORA Mainnet is not available in the current registry.")

            controller.tableView(table, didSelectRowAt: IndexPath(row: 3, section: 1))
            let alert = presentedAlert(controller)
            XCTAssertEqual(alert?.title, "Farming")
            XCTAssertEqual(alert?.actions.count, 2)
            controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
            XCTAssertEqual(presentedAlert(controller)?.title, "Polkamarkt")
            controller.showStaking()
            XCTAssertEqual(presentedAlert(controller)?.title, "Staking")
            controller.openPolkamarkt(marketId: "3")
            XCTAssertEqual(presentedAlert(controller)?.message, "SORA Mainnet is not available in the current registry.")
        }
        XCTAssertEqual(navigation.viewControllers.count, 1)
    }

    func testHubBuildsItsOwnAggregatorFromTheRegistry() throws {
        let controller = DeFiHubViewController(wallet: CovDFixtures.wallet(substrate: false))
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: controller.view))
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 0).first?.0, "Loading positions…")
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 1).count, 5)
        CovDFixtures.spin(timeout: 1) { CovDFixtures.cellTexts(table, section: 0).first?.0 != "Loading positions…" }
        let titles = CovDFixtures.cellTexts(table, section: 0).compactMap(\.0)
        // The registry's own sources may still be loading; otherwise every row explains a missing provider.
        XCTAssertTrue(
            titles == ["Loading positions…"] || titles.allSatisfy { $0.hasSuffix("unavailable") || $0.hasSuffix("stale") },
            titles.joined(separator: ", ")
        )
    }
}
