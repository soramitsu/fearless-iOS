import Foundation
import SSFModels
import UIKit
import XCTest

@testable import fearless

struct CovDCrossChainProvider: CrossChainRouteProvider {
    let identifier = "covd-bridge"
    let displayName = "CovD bridge"
    let unavailableReason = "CovD bridge is offline."
    var routes: [CrossChainOriginRoute]

    func origins(wallet _: MetaAccountModel, chains _: [ChainModel]) -> [CrossChainOriginRoute] { routes }
}

final class CovDCrossChainRootTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private func route(_ chainAsset: ChainAsset, unavailableReason: String? = nil) throws -> CrossChainOriginRoute {
        let definition = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first)
        return CrossChainOriginRoute(
            providerId: "covd-bridge",
            chainAsset: chainAsset,
            canSign: unavailableReason == nil,
            unavailableReason: unavailableReason,
            protocolName: "XCM",
            destinationNames: ["Asset Hub", "Acala"],
            minimumDisplay: "0.1 XOR",
            feeDisplay: "0.01 XOR",
            estimatedTimeDisplay: "About 1 minute",
            warnings: [],
            reviewedContext: ReviewedCrossChainRouteContext(definition: definition, providerId: "covd-bridge")
        )
    }

    func testRoutesListOpenableOriginsAndExplainRefusedOnes() throws {
        let chain = CovDFixtures.soraChain()
        let xor = try XCTUnwrap(CovDFixtures.chainAsset(chain, currencyId: CovDFixtures.xorAssetId))
        let open = try route(xor)
        let refused = try route(xor, unavailableReason: "Destination is paused.")
        let controller = CrossChainRootViewController(
            wallet: CovDFixtures.wallet(),
            providers: [CovDCrossChainProvider(routes: [open, refused]), CovDCrossChainProvider(routes: [])],
            unavailableRouteInventory: []
        )
        let navigation = UINavigationController(rootViewController: controller)
        navigation.setNavigationBarHidden(true, animated: false)
        window = try CovDFixtures.host(navigation)
        XCTAssertFalse(navigation.isNavigationBarHidden)
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: controller.view))

        let routes = CovDFixtures.cellTexts(table, section: 0)
        XCTAssertEqual(routes.map(\.0), ["SORA → Asset Hub, Acala · XOR", "SORA → Asset Hub, Acala · XOR"])
        XCTAssertEqual(routes.map(\.1), ["Minimum: 0.1 XOR · Fee: 0.01 XOR · About 1 minute", "Destination is paused."])
        let providers = CovDFixtures.cellTexts(table, section: 1)
        XCTAssertEqual(providers.map(\.0), ["CovD bridge", "CovD bridge", "Other networks"])
        XCTAssertEqual(providers.map(\.1).prefix(2), ["Available", "CovD bridge is offline."])
        XCTAssertEqual(table.dataSource?.tableView(table, numberOfRowsInSection: 7), 0)

        // A reviewed route that this build cannot assemble is explained instead of opened.
        table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(CovDFixtures.spin { controller.presentedViewController != nil })
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, "No supported route")
        XCTAssertEqual(alert.message, "A transfer route could not be created for SORA and XOR.")
        XCTAssertEqual(navigation.viewControllers.count, 1)
        alert.dismiss(animated: false)
        XCTAssertTrue(CovDFixtures.spin { controller.presentedViewController == nil })

        table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: 0, section: 1))
        table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: 5, section: 0))
        XCTAssertNil(controller.presentedViewController)
    }

    func testEmptyInventoryShowsASingleExplanatoryRow() throws {
        let controller = CrossChainRootViewController(wallet: CovDFixtures.wallet(), providers: [], unavailableRouteInventory: [])
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        let table = try XCTUnwrap(CovDFixtures.findTableView(in: controller.view))
        let rows = CovDFixtures.cellTexts(table, section: 0)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.0, "No cross-chain routes")
        XCTAssertEqual(rows.first?.1, ReviewedXcmExecutionAuthority.unavailableReason)
        XCTAssertEqual(CovDFixtures.cellTexts(table, section: 1).map(\.0), ["Other networks"])
    }

    func testUnavailableRouteDefinitionsNameTheirOriginAsset() throws {
        let definition = try XCTUnwrap(CrossChainProviderRegistry.defaultProviders.flatMap(\.reviewedUnavailableRoutes).first)
        XCTAssertEqual(definition.assetKey.chainId, definition.originChainId)
        XCTAssertEqual(definition.assetKey.assetId, definition.originCanonicalAssetId)
        XCTAssertEqual(definition.assetKey.ecosystem, definition.originEcosystem)
    }
}
