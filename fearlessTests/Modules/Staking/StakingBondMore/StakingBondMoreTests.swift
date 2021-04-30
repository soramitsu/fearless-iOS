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
            when(stub).didReceiveInput(viewModel: any()).thenDoNothing()
            when(stub).didReceiveFee(viewModel: any()).thenDoNothing()
            when(stub).didReceiveAsset(viewModel: any()).thenDoNothing()
        }

        // given
        let continueExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showConfirmation(from: any()).then { _ in
                continueExpectation.fulfill()
            }
        }
        // balance & fee is received
        presenter.didReceive(balance: DyAccountData(free: 100000000000000, reserved: 0, miscFrozen: 0, feeFrozen: 0))
        let paymentInfo = RuntimeDispatchInfo(dispatchClass: "normal", fee: "12600002654", weight: 331759000)
        presenter.didReceive(paymentInfo: paymentInfo, for: 10)

        // when
        presenter.handleContinueAction()

        // then
        wait(for: [continueExpectation], timeout: Constants.defaultExpectationDuration)



        // given
        let errorAlertExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).present(message: any(), title: any(), closeAction: any(), from: any()).then { _ in
                errorAlertExpectation.fulfill()
            }
        }
        // empty balance & extra fee is received
        presenter.didReceive(balance: nil)
        let paymentInfoWithExtraFee = RuntimeDispatchInfo(dispatchClass: "normal", fee: "12600000000002654", weight: 331759000)
        presenter.didReceive(paymentInfo: paymentInfoWithExtraFee, for: 1)

        // when
        presenter.handleContinueAction()

        // then
        wait(for: [errorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
