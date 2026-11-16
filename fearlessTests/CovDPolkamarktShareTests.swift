import Foundation
import UIKit
import XCTest

@testable import fearless

final class CovDPolkamarktShareTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    func testShareButtonOffersTheMarketDeepLink() throws {
        let market = PolkamarktMarket(
            marketId: "31", conditionId: "4", creator: "cnA", title: "Will it rain?", marketDescription: "d",
            category: "Weather", closeBlock: "100", liquidityUSD: "12", volumeUSD: "3",
            yesProbability: "0.5", indexedStatus: "Open", mechanism: nil, runtimeState: nil
        )
        let controller = PolkamarktMarketDetailViewController(
            market: market,
            currentBlock: "16",
            capabilities: CovDPolkamarktMutationTests.complete,
            service: CovDPolkamarktLiveServiceTests.makeService(historyURL: nil),
            submissionAuthorizer: CovDSubmissionAuthorizerStub()
        )
        window = try CovDFixtures.host(UINavigationController(rootViewController: controller))
        let share = try XCTUnwrap(controller.navigationItem.rightBarButtonItem)
        let action = try XCTUnwrap(share.action)
        XCTAssertTrue(share.target === controller)
        _ = controller.perform(action)
        XCTAssertTrue(CovDFixtures.spin { controller.presentedViewController is UIActivityViewController })
        XCTAssertEqual(PolkamarktMarketDetailViewController.natural("1500000000000000000"), "1.5")
        XCTAssertEqual(PolkamarktMarketDetailViewController.natural("not-planks"), "not-planks")
    }
}
