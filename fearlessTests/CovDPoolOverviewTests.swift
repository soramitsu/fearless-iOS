import Foundation
import SoraFoundation
import SSFModels
import UIKit
import XCTest

@testable import fearless

final class CovDPoolOverviewRouterSpy: CovDRouterSpy, LiquidityPoolsOverviewRouterInput {
    var available = 0
    var user = 0
    func showAllAvailablePools(chain _: ChainModel, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?, moduleOutput _: LiquidityPoolsListModuleOutput?) {
        available += 1
    }
    func showAllUserPools(chain _: ChainModel, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?, moduleOutput _: LiquidityPoolsListModuleOutput?) {
        user += 1
    }
}

final class CovDPoolListInputSpy: LiquidityPoolsListModuleInput {
    var refreshes = 0
    var resets = 0
    func resetTasks() { resets += 1 }
    func refreshData() { refreshes += 1 }
}

final class CovDPoolTransactionObserver: TransactionObserver {
    var hashes: [String] = []
    func subscribe(transactionHash: String) async throws -> AsyncThrowingStream<ExtrinsicStatus, Error> {
        hashes.append(transactionHash)
        return AsyncThrowingStream {
            $0.yield(.ready)
            $0.yield(.inBlock("0xblock"))
            $0.yield(.finalized("0xfinal"))
            $0.finish()
        }
    }
}

final class CovDPoolOverviewTests: XCTestCase {
    func testEmbeddedListsResizeRefreshAndReactOnlyToFinalizedTransactions() throws {
        let observer = CovDPoolTransactionObserver()
        let router = CovDPoolOverviewRouterSpy()
        let presenter = LiquidityPoolsOverviewPresenter(
            interactor: LiquidityPoolsOverviewInteractor(transactionObserver: observer), router: router,
            localizationManager: LocalizationManager.shared, chain: CovDLiquidityFixtures.chain(), wallet: CovDFixtures.wallet()
        )
        let userInput = CovDPoolListInputSpy()
        let availableInput = CovDPoolListInputSpy()
        presenter.userPoolsInput = userInput
        presenter.availablePoolsInput = availableInput
        let user = UIViewController()
        let available = UIViewController()
        let controller = LiquidityPoolsOverviewViewController(
            output: presenter, localizationManager: LocalizationManager.shared,
            userPoolsViewController: user, availablePoolsViewController: available
        )
        let window = try CovDFixtures.host(controller)
        defer { CovDFixtures.tearDown(window) }
        let layout = controller.rootView
        XCTAssertEqual(controller.children.count, 2)
        XCTAssertTrue(user.view.superview === layout.userPoolsContainerView)
        XCTAssertTrue(available.view.superview === layout.availablePoolsContainerView)
        XCTAssertTrue(layout.userPoolsContainerView.isHidden)
        presenter.shouldShowUserPools(true)
        presenter.didReceiveUserPoolCount(2)
        layout.layoutIfNeeded()
        XCTAssertFalse(layout.userPoolsContainerView.isHidden)
        let expected = LiquidityPoolConstants.liquidityPoolsListHeaderHeight + 2 * LiquidityPoolConstants.liquidityPoolsListCellHeight + 12
        XCTAssertEqual(layout.userPoolsContainerView.bounds.height, expected, accuracy: 1)
        XCTAssertGreaterThan(layout.availablePoolsContainerView.bounds.height, 0)
        presenter.didReceiveUserPoolCount(0)
        layout.layoutIfNeeded()
        XCTAssertEqual(layout.userPoolsContainerView.bounds.height, 0)
        layout.scrollView.refreshControl?.sendActions(for: .valueChanged)
        XCTAssertEqual(userInput.refreshes, 1)
        XCTAssertEqual(availableInput.refreshes, 1)
        presenter.didSubmitTransaction(transactionHash: "0xtransaction")
        XCTAssertTrue(CovDFixtures.spin { userInput.refreshes == 2 && availableInput.refreshes == 2 })
        XCTAssertEqual(observer.hashes, ["0xtransaction"])
        presenter.didTapMoreUserPools()
        presenter.didTapMoreAvailablePools()
        XCTAssertEqual(router.user, 1)
        XCTAssertEqual(router.available, 1)
        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertEqual(userInput.resets, 1)
        XCTAssertEqual(availableInput.resets, 1)
    }
}
