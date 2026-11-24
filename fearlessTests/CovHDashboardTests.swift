import SSFModels
import UIKit
import XCTest
@testable import fearless

/// The chain-account dashboard container: presenter forwarding, view controller and its factories.
final class CovHDashboardTests: XCTestCase {
    func testPresenterForwardsHistoryUpdatesToTheEmbeddedHistory() {
        let interactor = WalletChainAccountDashboardInteractor()
        let presenter = WalletChainAccountDashboardPresenter(interactor: interactor, wireframe: WalletChainAccountDashboardWireframe())
        interactor.presenter = presenter
        XCTAssertTrue(interactor.presenter === presenter)

        let history = CovHDashboardHistoryInput()
        presenter.transactionHistoryModuleInput = history
        presenter.setup()
        let chainAsset = ChainAsset(chain: CovHTxHistoryFixture.chain(history: nil), asset: CovHTxHistoryFixture.main)
        presenter.updateTransactionHistory(for: chainAsset)
        presenter.updateTransactionHistory(for: nil)
        XCTAssertEqual(history.updates.map { $0?.chainAssetId }, [chainAsset.chainAssetId, nil])
    }

    func testControllerLoadsItsLayoutAndSetsUpThePresenter() {
        let presenter = CovHDashboardPresenterSpy()
        let controller = WalletChainAccountDashboardViewController(presenter: presenter)
        controller.loadViewIfNeeded()
        XCTAssertTrue(controller.view is WalletChainAccountDashboardViewLayout)
        XCTAssertEqual(presenter.setups, 1)
        XCTAssertEqual(controller.supportsAdaptiveColumns, UIDevice.current.userInterfaceIdiom == .pad)
        XCTAssertTrue(controller.controller === controller)
    }

    func testFactoriesNeedASelectedWallet() {
        let chainAsset = ChainAsset(chain: CovHTxHistoryFixture.chain(history: nil), asset: CovHTxHistoryFixture.main)
        let details = WalletChainAccountDashboardViewFactory.createDetailsView(chainAsset: chainAsset)
        let networks = WalletChainAccountDashboardViewFactory.createNetworksView(chainAsset: chainAsset)
        if SelectedWalletSettings.shared.value == nil {
            XCTAssertNil(details)
            XCTAssertNil(networks)
        } else {
            XCTAssertTrue(details == nil || details is WalletChainAccountDashboardViewController)
            XCTAssertTrue(networks == nil || networks is WalletChainAccountDashboardViewController)
        }
    }
}

final class CovHDashboardHistoryInput: WalletTransactionHistoryModuleInput {
    private(set) var updates: [ChainAsset?] = []

    func updateTransactionHistory(for chainAsset: ChainAsset?) { updates.append(chainAsset) }
}

final class CovHDashboardPresenterSpy: WalletChainAccountDashboardPresenterProtocol {
    private(set) var setups = 0

    func setup() { setups += 1 }
}
