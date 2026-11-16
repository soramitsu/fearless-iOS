import XCTest
import SoraFoundation
@testable import fearless

/// UIKit asks a container to tell each child it adds that the move is complete. These screens sent that message to
/// themselves (`controller` is the container's own ControllerBackedProtocol view), so no embedded child received it.
final class ChildControllerContainmentTests: XCTestCase {
    func testChainAccountCompletesTheMoveOfItsBalanceChild() {
        let child = ContainmentChildSpy()
        let controller = ChainAccountViewController(
            presenter: CovHChainAccountPresenterSpy(),
            balanceInfoViewController: child,
            localizationManager: LocalizationManager.shared,
            mode: .extended
        )

        controller.loadViewIfNeeded()

        XCTAssertTrue(child.parent === controller)
        XCTAssertEqual(child.completedMoves.map { $0 === controller }, [true])
    }

    func testWalletMainContainerCompletesTheMoveOfItsBalanceChild() {
        let child = ContainmentChildSpy()
        let controller = WalletMainContainerViewController(
            balanceInfoViewController: child,
            pageControllers: [UIViewController(), UIViewController()],
            output: CovHWMCViewOutputSpy(),
            localizationManager: LocalizationManager.shared
        )

        controller.loadViewIfNeeded()

        XCTAssertEqual(child.completedMoves.map { $0 === controller }, [true])
    }

    func testAssetListSearchCompletesTheMoveOfItsListChild() {
        let child = ContainmentChildSpy()
        let controller = AssetListSearchViewController(
            assetListViewController: child,
            output: CovJSelAssetListSearchOutputSpy(),
            localizationManager: LocalizationManager.shared
        )

        controller.loadViewIfNeeded()

        XCTAssertEqual(child.completedMoves.map { $0 === controller }, [true])
    }

    func testMultichainAssetSelectionCompletesTheMoveOfItsSelectionChild() {
        let child = ContainmentChildSpy()
        let controller = MultichainAssetSelectionViewController(
            output: CovJSelMultichainOutputSpy(),
            localizationManager: LocalizationManager.shared,
            selectAssetViewController: child
        )

        controller.loadViewIfNeeded()

        XCTAssertEqual(child.completedMoves.map { $0 === controller }, [true])
    }

    func testLiquidityPoolsOverviewCompletesTheMoveOfBothPoolChildren() {
        let user = ContainmentChildSpy()
        let available = ContainmentChildSpy()
        let controller = LiquidityPoolsOverviewViewController(
            output: ContainmentPoolsOverviewOutput(),
            localizationManager: LocalizationManager.shared,
            userPoolsViewController: user,
            availablePoolsViewController: available
        )

        controller.loadViewIfNeeded()

        XCTAssertEqual(user.completedMoves.map { $0 === controller }, [true])
        XCTAssertEqual(available.completedMoves.map { $0 === controller }, [true])
    }

    func testPolkaswapAdjustmentCompletesTheMoveOfItsBannersChild() {
        let child = ContainmentChildSpy()
        let controller = PolkaswapAdjustmentViewController(
            output: CovDAdjustmentTapSpy(),
            bannersViewController: child,
            localizationManager: LocalizationManager.shared
        )

        controller.loadViewIfNeeded()

        XCTAssertEqual(child.completedMoves.map { $0 === controller }, [true])
    }
}

private final class ContainmentChildSpy: UIViewController {
    private(set) var completedMoves: [UIViewController?] = []

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        completedMoves.append(parent)
    }
}

private final class ContainmentPoolsOverviewOutput: LiquidityPoolsOverviewViewOutput {
    func didLoad(view _: LiquidityPoolsOverviewViewInput) {}
    func backButtonClicked() {}
    func handleRefreshControlEvent() {}
}
