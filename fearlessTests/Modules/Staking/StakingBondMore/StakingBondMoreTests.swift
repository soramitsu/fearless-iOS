import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
import CommonWallet
@testable import fearless

class StakingBondMoreTests: XCTestCase {

    func testContinueAction() {
        let wireframe = MockStakingBondMoreWireframeProtocol()
        let interactor = MockStakingBondMoreInteractorInputProtocol()
        let balanceViewModelFactory = StubBalanceViewModelFactory()
        let stubAsset = WalletAsset(
            identifier: "",
            name: .init(closure: { _ in "" }),
            symbol: "",
            precision: 0
        )
        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            asset: stubAsset
        )
        let view = MockStakingBondMoreViewProtocol()
        presenter.view = view

        stub(view) { stub in
            when(stub).localizationManager.get.then { _ in nil }
        }

        // given
        let continueExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showConfirmation(from: any()).then { _ in
                continueExpectation.fulfill()
            }
        }

        // when
        presenter.handleContinueAction()

        // then
        wait(for: [continueExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
