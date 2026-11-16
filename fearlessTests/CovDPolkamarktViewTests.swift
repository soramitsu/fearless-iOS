import BigInt
import Foundation
import SoraKeystore
import SSFModels
import UIKit
import XCTest

@testable import fearless

struct CovDRuntimeCatalogStub: PolkamarktRuntimeCatalogProviding {
    var entries: [PolkamarktRuntimeMarketEntry] = []
    var error: Error?

    func markets() async throws -> [PolkamarktRuntimeMarketEntry] {
        if let error { throw error }
        return entries
    }
}

final class CovDAccountCapabilityStub: PolkamarktAccountCapabilityProviding {
    var capability: PolkamarktAccountCapability

    init(capability: PolkamarktAccountCapability) {
        self.capability = capability
    }

    func accountCapability() async -> PolkamarktAccountCapability { capability }
}

final class CovDPolkamarktLiveServiceTests: XCTestCase {
    static let funded = PolkamarktAccountCapability(
        hasSoraAccount: true,
        collateralAssetKey: AssetKey(ecosystem: "substrate", chainId: "c", assetId: CovDFixtures.kusdAssetId),
        feeAssetKey: AssetKey(ecosystem: "substrate", chainId: "c", assetId: CovDFixtures.xorAssetId),
        collateralSpendable: BigUInt(2_000_000_000_000_000_000),
        feeSpendable: BigUInt(500_000_000_000_000_000)
    )

    static func makeTransports() -> (rpc: CovDRoutingTransport, indexer: CovDRoutingTransport) {
        let rpc = CovDRoutingTransport()
        rpc.setRPC("chain_getHeader", result: ["number": "0x10"])
        rpc.setRPC("rpc_methods", result: ["methods": ["polkamarkt_marketState", "polkamarkt_claimable"]])
        rpc.setRPC("polkamarkt_marketState", result: ["marketId": "1", "dpmCollateral": "40", "impliedYesProbabilityBps": "5000"])
        rpc.setRPC("polkamarkt_claimable", result: [
            "marketId": "1", "account": "cnA", "status": "Resolved", "traderPayout": "3000000000000000000",
            "creatorFees": "1000000000000000000", "isCreator": true
        ])
        let indexer = CovDRoutingTransport()
        indexer.setGraphQL("PolkamarktLatestMarkets", response: ["data": ["markets": ["edges": [
            ["node": ["id": "1", "marketId": "1", "title": "Indexed market", "category": "Crypto", "closeBlock": "100", "liquidityUSD": "10"]]
        ]]]])
        indexer.setGraphQL("marketSnapshots", response: ["data": ["marketSnapshots": ["edges": [
            ["node": ["id": "h1", "blockHeight": "5", "probability": "0.25"]],
            ["node": ["id": "h2", "blockHeight": "6", "probability": "0.5"]]
        ]]]])
        indexer.setGraphQL("accountPositions", response: ["data": ["accountPositions": ["edges": [
            ["node": ["id": "p1", "marketId": "1", "outcome": "yes", "shares": "2000000000000000000", "status": "Open"]]
        ]]]])
        indexer.setGraphQL("trades(first", response: ["data": ["trades": ["edges": [
            ["node": ["id": "t1", "marketId": "1", "side": "buy", "outcome": "no", "collateral": "1000000000000000000",
                      "sharesOut": "2000000000000000000", "fee": "10000000000000000", "blockNumber": "8"]]
        ]]]])
        return (rpc, indexer)
    }

    static func makeService(
        wallet: MetaAccountModel = CovDFixtures.wallet(),
        nodeURL: String? = "wss://sora.invalid/public-ws",
        historyURL: String? = "https://indexer.invalid/graphql",
        catalog: CovDRuntimeCatalogStub = CovDRuntimeCatalogStub(),
        capability: PolkamarktAccountCapability = funded,
        transports: (rpc: CovDRoutingTransport, indexer: CovDRoutingTransport) = makeTransports()
    ) -> PolkamarktLiveService {
        PolkamarktLiveService(
            wallet: wallet,
            chain: CovDFixtures.soraChain(nodeURL: nodeURL, historyURL: historyURL),
            runtimeCatalog: catalog,
            accountCapabilityProvider: CovDAccountCapabilityStub(capability: capability),
            rpcTransport: transports.rpc,
            indexerTransport: transports.indexer
        )
    }

    func testSnapshotMergesIndexerRuntimeAndMarketState() async throws {
        let catalog = CovDRuntimeCatalogStub(entries: [
            PolkamarktRuntimeMarketEntry(
                marketId: "2", conditionId: "4", creator: nil, closeBlock: "90",
                status: "Open", mechanism: "DynamicPariMutuel", question: "Runtime market", category: nil
            )
        ])
        let service = Self.makeService(catalog: catalog)
        XCTAssertNotNil(service.rpcClient)
        XCTAssertNotNil(service.indexerClient)

        let snapshot = try await service.snapshot()
        XCTAssertEqual(snapshot.currentBlock, "16")
        XCTAssertTrue(snapshot.capabilities.hasRPC("marketState"))
        XCTAssertFalse(snapshot.capabilities.palletAvailable)
        XCTAssertEqual(Set(snapshot.markets.map(\.marketId)), ["1", "2"])
        XCTAssertTrue(snapshot.markets.allSatisfy { $0.runtimeState != nil })
        XCTAssertTrue(snapshot.markets.allSatisfy { $0.liquidityUSD == "40" })
    }

    func testSnapshotFailsOnlyWhenEveryCatalogIsEmptyAfterIndexerFailure() async throws {
        let transports = Self.makeTransports()
        let failingIndexer = CovDRoutingTransport()
        let failing = Self.makeService(transports: (transports.rpc, failingIndexer))
        do {
            _ = try await failing.snapshot()
            XCTFail("expected indexer failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.invalidResponse.localizedDescription)
        }

        let offline = Self.makeService(nodeURL: nil, historyURL: nil)
        XCTAssertNil(offline.rpcClient)
        XCTAssertNil(offline.indexerClient)
        let empty = try await offline.snapshot()
        XCTAssertEqual(empty.currentBlock, "0")
        XCTAssertTrue(empty.markets.isEmpty)
        XCTAssertTrue(empty.capabilities.rpc.isEmpty)
    }

    func testAccountReadsUseTheWalletAddressAndFailClosed() async throws {
        let service = Self.makeService()
        let history = await service.history(marketId: "1")
        XCTAssertEqual(history.map(\.id), ["h1", "h2"])
        let positions = await service.positions()
        XCTAssertEqual(positions.map(\.id), ["p1"])
        let activity = await service.indexedActivity()
        XCTAssertEqual(activity.trades.map(\.id), ["t1"])
        let claimable = await service.claimable(marketId: "1")
        XCTAssertEqual(claimable?.creatorFees, "1000000000000000000")
        let capability = await service.accountCapability()
        XCTAssertEqual(capability, Self.funded)

        let noAccount = Self.makeService(wallet: CovDFixtures.wallet(substrate: false))
        let noPositions = await noAccount.positions()
        XCTAssertTrue(noPositions.isEmpty)
        let noClaim = await noAccount.claimable(marketId: "1")
        XCTAssertNil(noClaim)
        do {
            _ = try await noAccount.indexedActivityResult()
            XCTFail("expected missing account")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Add a SORA account to load Polkamarkt positions.")
        }
        let emptyActivity = await noAccount.indexedActivity()
        XCTAssertTrue(emptyActivity.positions.isEmpty && emptyActivity.trades.isEmpty)

        let noIndexer = Self.makeService(historyURL: nil)
        do {
            _ = try await noIndexer.indexedActivityResult()
            XCTFail("expected missing indexer")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The SORA account indexer is unavailable.")
        }
        let noHistory = await noIndexer.history(marketId: "1")
        XCTAssertTrue(noHistory.isEmpty)
    }

    func testSubmissionAuthorizerFailsClosedBeforeTouchingTheRuntime() async {
        let wallet = CovDFixtures.wallet()
        let registry = CovDRegistryStub()
        let authorizer = PolkamarktMutationSubmissionAuthorizer(
            wallet: wallet,
            chain: CovDFixtures.soraChain(),
            callBuilder: PolkamarktMutationCallBuilder(),
            chainRegistry: registry,
            settings: InMemorySettingsManager(),
            keystore: InMemoryKeychain(),
            selectedWallet: { wallet }
        )
        do {
            _ = try await authorizer.authorize(.claimTrader(marketId: "1"))
            XCTFail("expected a fail-closed policy error")
        } catch {
            let expected = [
                PolkamarktServiceError.actionsPaused.localizedDescription,
                "Read and accept the current Polkaswap disclaimer before submitting a Polkamarkt transaction on SORA."
            ]
            XCTAssertTrue(expected.contains(error.localizedDescription), error.localizedDescription)
        }
    }
}

final class CovDPolkamarktControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private func market(closeBlock: String = "100", probability: String? = "0.25") -> PolkamarktMarket {
        PolkamarktMarket(
            marketId: "1", conditionId: "4", creator: "cnA", title: "Will it rain?", marketDescription: "d",
            category: "Weather", closeBlock: closeBlock, liquidityUSD: "12", volumeUSD: "3",
            yesProbability: probability, indexedStatus: "Open", mechanism: nil, runtimeState: nil
        )
    }

    private func presentedTitle(_ controller: UIViewController) -> String? {
        CovDFixtures.spin { controller.presentedViewController != nil }
        let title = (controller.presentedViewController as? UIAlertController)?.title
        controller.presentedViewController?.dismiss(animated: false)
        CovDFixtures.spin { controller.presentedViewController == nil }
        return title
    }

    func testDetailControllerRendersLoadedBalancesHistoryAndClaims() throws {
        let service = CovDPolkamarktLiveServiceTests.makeService()
        let controller = PolkamarktMarketDetailViewController(
            market: market(),
            currentBlock: "16",
            capabilities: CovDPolkamarktMutationTests.complete,
            service: service,
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
        window = try CovDFixtures.host(controller)
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: controller.view))
        XCTAssertEqual(controller.title, "Market #1")
        XCTAssertEqual(table.numberOfSections, 5)

        XCTAssertTrue(CovDFixtures.spin { table.dataSource?.tableView(table, numberOfRowsInSection: 2) == 2 })
        let network = CovDFixtures.cellTexts(table, section: 0)
        XCTAssertEqual(network.first?.0, "SORA · KUSD collateral · XOR fees")
        XCTAssertEqual(network.first?.1, "Spendable: 2 KUSD · 0.5 XOR")
        let details = CovDFixtures.cellTexts(table, section: 1)
        XCTAssertEqual(details.map(\.0), ["Status", "Category", "YES probability", "Liquidity"])
        XCTAssertEqual(details.map(\.1), ["Open", "Weather", "25%", "12 KUSD"])
        let history = CovDFixtures.cellTexts(table, section: 2)
        XCTAssertEqual(history.map(\.0), ["Block 5", "Block 6"])
        XCTAssertEqual(history.map(\.1), ["YES 25%", "YES 50%"])
        let trade = CovDFixtures.cellTexts(table, section: 3)
        XCTAssertEqual(trade.map(\.0), ["Buy YES with KUSD", "Buy NO with KUSD", "Sell YES for KUSD", "Sell NO for KUSD"])
        XCTAssertTrue(trade.allSatisfy { $0.1 == "Quote from the SORA runtime" })
        let claims = CovDFixtures.cellTexts(table, section: 4)
        XCTAssertEqual(claims.map(\.0), ["Claim trader payout", "Claim creator fees"])
        XCTAssertEqual(claims.map(\.1), ["3 KUSD · fee paid in XOR", "1 KUSD · fee paid in XOR"])
        let titles = (0 ..< 6).map { table.dataSource?.tableView?(table, titleForHeaderInSection: $0) }
        XCTAssertEqual(titles, ["Network and collateral", "Will it rain?", "YES probability history", "Trade", "Claims", nil])
        XCTAssertEqual(table.dataSource?.tableView(table, numberOfRowsInSection: 9), 0)
    }

    func testDetailControllerExplainsWhyTradesAndClaimsCannotStart() throws {
        let unavailable = PolkamarktRuntimeCapabilities(
            palletAvailable: false, storage: [], rpc: [], calls: [], claimablePayoutFieldAvailable: false
        )
        let closedController = PolkamarktMarketDetailViewController(
            market: market(closeBlock: "10", probability: nil),
            currentBlock: "16",
            capabilities: unavailable,
            service: CovDPolkamarktLiveServiceTests.makeService(historyURL: nil),
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
        window = try CovDFixtures.host(closedController)
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: closedController.view))
        let details = CovDFixtures.cellTexts(table, section: 1)
        XCTAssertEqual(details[0].1, "Closed")
        XCTAssertEqual(details[2].1, "Unavailable")
        let history = CovDFixtures.cellTexts(table, section: 2)
        XCTAssertEqual(history.first?.0, "Probability history unavailable")
        XCTAssertTrue(CovDFixtures.cellTexts(table, section: 3).allSatisfy { $0.1 == unavailable.tradingUnavailableReason })

        closedController.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 3))
        XCTAssertEqual(presentedTitle(closedController), "Market closed")

        let openController = PolkamarktMarketDetailViewController(
            market: market(),
            currentBlock: "16",
            capabilities: unavailable,
            service: CovDPolkamarktLiveServiceTests.makeService(),
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
        CovDFixtures.tearDown(window)
        window = try CovDFixtures.host(openController)
        let openTable = try XCTUnwrap(CovDFixtures.findTableView(in: openController.view))
        openController.tableView(openTable, didSelectRowAt: IndexPath(row: 1, section: 3))
        XCTAssertEqual(presentedTitle(openController), "Trading unavailable")
        openController.tableView(openTable, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertNil(openController.presentedViewController)

        let tradable = PolkamarktMarketDetailViewController(
            market: market(),
            currentBlock: "16",
            capabilities: CovDPolkamarktMutationTests.complete,
            service: CovDPolkamarktLiveServiceTests.makeService(),
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
        CovDFixtures.tearDown(window)
        window = try CovDFixtures.host(tradable)
        let tradableTable = try XCTUnwrap(CovDFixtures.findTableView(in: tradable.view))
        let paused = !MultiChainFeaturePolicy.current.polkamarktMutationsEnabled
        tradable.tableView(tradableTable, didSelectRowAt: IndexPath(row: 2, section: 3))
        let tradeTitle = presentedTitle(tradable)
        tradable.tableView(tradableTable, didSelectRowAt: IndexPath(row: 1, section: 4))
        let claimTitle = presentedTitle(tradable)
        if paused {
            XCTAssertEqual(tradeTitle, "Actions paused")
            XCTAssertEqual(claimTitle, "Actions paused")
        } else {
            XCTAssertNotNil(tradeTitle)
            XCTAssertNotNil(claimTitle)
        }
    }

    func testNaturalFormattingFallsBackToRawValue() {
        XCTAssertEqual(PolkamarktMarketDetailViewController.natural("1500000000000000000"), "1.5")
        XCTAssertEqual(PolkamarktMarketDetailViewController.natural("not-a-number"), "not-a-number")
    }

    func testPositionsControllerListsIndexedPositionsAndTrades() throws {
        let controller = PolkamarktPositionsViewController(service: CovDPolkamarktLiveServiceTests.makeService())
        window = try CovDFixtures.host(controller)
        XCTAssertEqual(controller.title, "Positions & activity")
        let table = controller.tableView!
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 0).first?.0, "No Polkamarkt positions")
        XCTAssertTrue(CovDFixtures.spin {
            CovDFixtures.cellTexts(table, section: 0).first?.0 == "Market #1 · YES"
        })
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 0).first?.1, "2 shares · Open")
        let trade = CovDFixtures.cellTexts(table, section: 1).first
        XCTAssertEqual(trade?.0, "Buy NO · market #1")
        XCTAssertEqual(trade?.1, "1 KUSD · 2 shares · fee 0.01 KUSD · block 8")
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 0), "Your positions")
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 1), "Indexed trade activity")
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
    }

    func testPositionsControllerShowsEmptyActivity() throws {
        let controller = PolkamarktPositionsViewController(
            service: CovDPolkamarktLiveServiceTests.makeService(wallet: CovDFixtures.wallet(substrate: false))
        )
        window = try CovDFixtures.host(controller)
        let table = controller.tableView!
        CovDFixtures.spin(timeout: 0.3) { false }
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 0).first?.0, "No Polkamarkt positions")
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 1).first?.0, "No indexed trade activity")
    }

    func testMarketListLoadsOfflineSnapshotSearchesAndOpensPositions() throws {
        let chain = CovDFixtures.soraChain(nodeURL: nil, historyURL: nil)
        let list = PolkamarktMarketListViewController(wallet: CovDFixtures.wallet(), chain: chain, marketId: "9")
        let navigation = UINavigationController(rootViewController: list)
        window = try CovDFixtures.host(navigation)
        list.loadViewIfNeeded()
        XCTAssertEqual(list.title, "Polkamarkt")
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: list.view))
        XCTAssertEqual(table.numberOfSections, 2)
        XCTAssertEqual(table.dataSource?.tableView?(table, titleForHeaderInSection: 0), "Open markets")
        XCTAssertEqual(table.dataSource?.tableView?(table, titleForHeaderInSection: 1), "Closed and resolved")
        XCTAssertTrue(CovDFixtures.spin { CovDFixtures.cellTexts(table, section: 0).first?.0 == "No active markets" })
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 1).count, 0)

        let search = try XCTUnwrap(list.navigationItem.searchController)
        XCTAssertEqual(search.searchBar.placeholder, "Search title, category, or market ID")
        search.searchBar.text = "  rain  "
        list.updateSearchResults(for: search)
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 0).first?.1, "Closed markets and positions remain available below.")
        list.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(navigation.viewControllers.count, 1)

        let positions = try XCTUnwrap(list.navigationItem.rightBarButtonItems?.first)
        XCTAssertEqual(positions.title, "Positions")
        _ = positions.target?.perform(positions.action)
        XCTAssertTrue(CovDFixtures.spin { navigation.viewControllers.count == 2 })
        XCTAssertTrue(navigation.topViewController is PolkamarktPositionsViewController)
    }
}
