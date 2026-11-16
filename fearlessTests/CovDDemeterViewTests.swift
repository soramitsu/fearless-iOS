import BigInt
import Foundation
import SSFModels
import UIKit
import XCTest

@testable import fearless

final class CovDDemeterFormattingTests: XCTestCase {
    typealias CovDF = CovDDemeterFixtures

    func testSymbolsPrecisionAndNaturalAmounts() {
        let chain = CovDF.pricedChain()
        XCTAssertEqual(DemeterFormatting.symbol(for: CovDF.pool.uppercased(), in: chain), "VAL")
        XCTAssertEqual(DemeterFormatting.symbol(for: "0x0200999999999999999999999999999999999999999999999999999999999999", in: chain), "0x0200…9999")
        XCTAssertEqual(DemeterFormatting.symbol(for: "short", in: chain), "short")
        XCTAssertEqual(DemeterFormatting.precision(for: "unknown", in: chain), 18)
        XCTAssertEqual(DemeterFormatting.natural("2500000000000000000", assetId: CovDF.pool, chain: chain), Decimal(string: "2.5"))
        XCTAssertNil(DemeterFormatting.natural("x", assetId: CovDF.pool, chain: chain))
        XCTAssertEqual(DemeterFormatting.naturalString("x", assetId: CovDF.pool, chain: chain), "x")
        XCTAssertEqual(DemeterFormatting.naturalString("1000000000000000000", assetId: CovDF.pool, chain: chain), "1")
    }

    func testTvlAndAprUseExactCachedPrices() {
        let chain = CovDF.pricedChain()
        let wallet = CovDFixtures.wallet()
        let pool = CovDF.makePool()
        XCTAssertEqual(DemeterFormatting.tvl(pool: pool, wallet: wallet, chain: chain), Decimal(8))
        XCTAssertEqual(DemeterFormatting.apr(pool: pool, token: CovDF.token, wallet: wallet, chain: chain), Decimal(49_275_000))
        XCTAssertNil(DemeterFormatting.apr(pool: pool, token: nil, wallet: wallet, chain: chain))
        XCTAssertNil(DemeterFormatting.apr(pool: CovDF.makePool(isFarm: false), token: CovDF.token, wallet: wallet, chain: chain))

        let unpriced = CovDFixtures.soraChain()
        XCTAssertNil(DemeterFormatting.tvl(pool: pool, wallet: wallet, chain: unpriced))
        XCTAssertNil(DemeterFormatting.apr(pool: pool, token: CovDF.token, wallet: wallet, chain: unpriced))
    }
}

final class CovDDemeterControllerTests: XCTestCase {
    typealias CovDF = CovDDemeterFixtures
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private func presentedTitle(_ controller: UIViewController) -> String? {
        CovDFixtures.spin { controller.presentedViewController != nil }
        let title = (controller.presentedViewController as? UIAlertController)?.title
        controller.presentedViewController?.dismiss(animated: false)
        CovDFixtures.spin { controller.presentedViewController == nil }
        return title
    }

    private func detail(
        chain: ChainModel,
        pool: DemeterPool,
        position: DemeterAccountPosition?,
        capabilities: DemeterRuntimeCapabilities = CovDDemeterFixtures.complete
    ) -> DemeterPoolDetailViewController {
        DemeterPoolDetailViewController(
            wallet: CovDFixtures.wallet(),
            chain: chain,
            pool: pool,
            token: CovDF.token,
            position: position,
            capabilities: capabilities,
            onMutation: {},
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
    }

    func testPoolDetailRendersPricesPositionAndActions() throws {
        let pool = CovDF.makePool()
        let controller = detail(chain: CovDF.pricedChain(), pool: pool, position: CovDF.position(pool, pooled: "3000000000000000000", rewards: "500000000000000000"))
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        XCTAssertEqual(controller.title, "Farm VAL")
        let table = controller.tableView!
        XCTAssertEqual(controller.numberOfSections(in: table), 3)
        XCTAssertEqual((0 ..< 4).map { controller.tableView(table, titleForHeaderInSection: $0) }, ["Pool", "Your position", "Actions", nil])
        let poolRows = CovDFixtures.cellTexts(table, section: 0)
        XCTAssertEqual(poolRows.map(\.0), ["Protocol", "Rewards", "APR", "TVL"])
        XCTAssertEqual(poolRows.map(\.1), ["SORA · Demeter Farming · XOR network fees", "PSWAP", "49275000%", "$8"])
        let position = CovDFixtures.cellTexts(table, section: 1)
        XCTAssertEqual(position.map(\.0), ["Deposited", "Claimable rewards"])
        XCTAssertEqual(position.map(\.1), ["3 VAL", "0.5 PSWAP"])
        let actions = CovDFixtures.cellTexts(table, section: 2)
        XCTAssertEqual(actions.map(\.0), ["Deposit", "Withdraw", "Claim rewards"])
        XCTAssertTrue(actions.allSatisfy { $0.1 == "Review amount and estimated XOR fee" })

        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertNil(controller.presentedViewController)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 2))
        CovDFixtures.spin { controller.presentedViewController != nil }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "Withdraw VAL")
        XCTAssertEqual(alert.textFields?.count, 1)
        XCTAssertEqual(alert.actions.map(\.title), ["Cancel", "Review"])
        alert.dismiss(animated: false)
        CovDFixtures.spin { controller.presentedViewController == nil }

        controller.tableView(table, didSelectRowAt: IndexPath(row: 2, section: 2))
        let claimTitle = presentedTitle(controller)
        XCTAssertTrue(["Actions paused", "Cannot sign"].contains(claimTitle ?? ""), claimTitle ?? "nil")
    }

    func testClosedPoolWithoutPricesExplainsUnavailableActions() throws {
        let pool = CovDF.makePool(isRemoved: true, isFarm: false)
        let unavailable = DemeterRuntimeCapabilities(palletAvailable: true, storage: ["Pools", "TokenInfos"], calls: [])
        let controller = detail(chain: CovDFixtures.soraChain(), pool: pool, position: nil, capabilities: unavailable)
        window = try CovDFixtures.host(controller)
        XCTAssertEqual(controller.title, "Stake 0x0200…0000")
        let table = controller.tableView!
        let poolRows = CovDFixtures.cellTexts(table, section: 0)
        XCTAssertEqual(poolRows[2].1, "Price unavailable")
        XCTAssertEqual(poolRows[3].1, "4 0x0200…0000 · fiat price unavailable")
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 1).map(\.1), ["0 0x0200…0000", "0 0x0200…0000"])
        let actions = CovDFixtures.cellTexts(table, section: 2)
        XCTAssertEqual(actions[0].1, "This pool is closed to new deposits.")
        XCTAssertEqual(actions[1].1, unavailable.unavailableReason)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 2))
        XCTAssertEqual(presentedTitle(controller), "Pool closed")
    }

    func testFarmingListWithoutRuntimeShowsEmptyStatesAndAlert() throws {
        let controller = DemeterFarmingViewController(wallet: CovDFixtures.wallet(), chain: CovDFixtures.soraChain())
        window = try CovDFixtures.host(controller)
        XCTAssertEqual(controller.title, "Demeter Farming")
        // Without a runtime the controller reports "Demeter unavailable" during viewDidLoad, before it has a window.
        let activity = try XCTUnwrap(controller.navigationItem.rightBarButtonItem?.customView as? UIActivityIndicatorView)
        XCTAssertFalse(activity.isAnimating)
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: controller.view))
        XCTAssertEqual(table.dataSource?.numberOfSections?(in: table), 2)
        XCTAssertEqual(table.dataSource?.tableView?(table, titleForHeaderInSection: 0), "Your positions")
        XCTAssertEqual(table.dataSource?.tableView?(table, titleForHeaderInSection: 1), "Farms and staking")
        XCTAssertEqual(table.dataSource?.tableView(table, numberOfRowsInSection: 5), 0)
        let positions = CovDFixtures.cellTexts(table, section: 0)
        XCTAssertEqual(positions.first?.0, "No active Demeter positions")
        XCTAssertEqual(positions.first?.1, "Positive deposits and unclaimed rewards appear here.")
        let pools = CovDFixtures.cellTexts(table, section: 1)
        XCTAssertEqual(pools.first?.0, "No Demeter pools")
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertNil(controller.presentedViewController)

        let watch = DemeterFarmingViewController(wallet: CovDFixtures.wallet(substrate: false), chain: CovDFixtures.soraChain())
        CovDFixtures.tearDown(window)
        window = try CovDFixtures.host(watch)
        let watchTable = try XCTUnwrap(CovDFixtures.findTableView(in: watch.view))
        XCTAssertEqual(CovDFixtures.cellTexts(watchTable, section: 0).first?.1, "Add a SORA account to see positions and sign actions.")
    }
}
