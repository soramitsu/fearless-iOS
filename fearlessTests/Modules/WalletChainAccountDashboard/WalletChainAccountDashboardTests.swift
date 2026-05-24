import XCTest
import UIKit
@testable import fearless

final class WalletChainAccountDashboardTests: XCTestCase {
    func testSetup_whenCalled_thenKeepsInjectedDependencies() {
        let interactor = WalletChainAccountDashboardInteractorInputSpy()
        let wireframe = WalletChainAccountDashboardWireframeSpy()
        let presenter = WalletChainAccountDashboardPresenter(
            interactor: interactor,
            wireframe: wireframe
        )
        let view = WalletChainAccountDashboardViewSpy()
        presenter.view = view

        presenter.setup()

        XCTAssertTrue(presenter.view === view)
        XCTAssertTrue(presenter.interactor === interactor)
        XCTAssertTrue(presenter.wireframe === wireframe)
    }

    func testUpdateTransactionHistory_whenChainAccountChanges_thenForwardsToHistoryModule() {
        let interactor = WalletChainAccountDashboardInteractorInputSpy()
        let wireframe = WalletChainAccountDashboardWireframeSpy()
        let presenter = WalletChainAccountDashboardPresenter(
            interactor: interactor,
            wireframe: wireframe
        )
        let historyInput = WalletTransactionHistoryModuleInputSpy()
        let chainAsset = ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("asset-id", symbol: "dot"),
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        )
        presenter.transactionHistoryModuleInput = historyInput

        presenter.updateTransactionHistory(for: chainAsset)
        presenter.updateTransactionHistory(for: nil)

        XCTAssertEqual(historyInput.receivedChainAssets.count, 2)
        XCTAssertEqual(historyInput.receivedChainAssets.first??.chain.chainId, chainAsset.chain.chainId)
        XCTAssertNil(historyInput.receivedChainAssets.last!)
    }
}

private final class WalletChainAccountDashboardViewSpy: WalletChainAccountDashboardViewProtocol {
    let controller = UIViewController()
    let isSetup = true
}

private final class WalletChainAccountDashboardInteractorInputSpy: WalletChainAccountDashboardInteractorInputProtocol {}

private final class WalletChainAccountDashboardWireframeSpy: WalletChainAccountDashboardWireframeProtocol {}

private final class WalletTransactionHistoryModuleInputSpy: WalletTransactionHistoryModuleInput {
    private(set) var receivedChainAssets: [ChainAsset?] = []

    func updateTransactionHistory(for chainAsset: ChainAsset?) {
        receivedChainAssets.append(chainAsset)
    }
}
