import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import fearless

class StakingBalanceTests: XCTestCase {

    func testStakingBalanceActions() {
        let interactor = MockStakingBalanceInteractorInputProtocol()
        let wireframe = MockStakingBalanceWireframeProtocol()
        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: MockStakingBalanceViewModelFactoryProtocol(),
            accountAddress: ""
        )
        let view = MockStakingBalanceViewProtocol()
        presenter.view = view

        stub(view) { stub in
            when(stub).localizationManager.get.then { _ in nil }
        }

        // given
        let presentErrorAlertExpectation = XCTestExpectation()
        let emptyController: AccountItem? = nil
        let emptyElectionStatus: ElectionStatus? = nil
        presenter.controller = emptyController
        presenter.electionStatus = emptyElectionStatus

        stub(wireframe) { stub in
            when(stub)
                .present(message: any(), title: any(), closeAction: any(), from: any())
                .then { _ in
                    presentErrorAlertExpectation.fulfill()
                }
        }
        // when
        presenter.handleAction(.bondMore)

        // then
        wait(for: [presentErrorAlertExpectation], timeout: Constants.defaultExpectationDuration)



        let stubController = AccountItem(address: "", cryptoType: .ecdsa, username: "", publicKeyData: Data())
        let closeElectionStatus = ElectionStatus.close
        presenter.controller = stubController
        presenter.electionStatus = closeElectionStatus

        // given
        let showBondMoreExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showBondMore(from: any()).then { _ in
                showBondMoreExpectation.fulfill()
            }
        }
        // when
        presenter.handleAction(.bondMore)

        // then
        wait(for: [showBondMoreExpectation], timeout: Constants.defaultExpectationDuration)

        // given
        let showUnbondExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showUnbond(from: any()).then { _ in
                showUnbondExpectation.fulfill()
            }
        }
        // when
        presenter.handleAction(.unbond)

        // then
        wait(for: [showUnbondExpectation], timeout: Constants.defaultExpectationDuration)



        // given
        let showRedeemExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).showRedeem(from: any()).then { _ in
                showRedeemExpectation.fulfill()
            }
        }
        // when
        presenter.handleAction(.redeem)

        // then
        wait(for: [showRedeemExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testCancelStakingBalanceModuleWhenStashItemIsNil() {
        let interactor = MockStakingBalanceInteractorInputProtocol()
        let wireframe = MockStakingBalanceWireframeProtocol()
        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: MockStakingBalanceViewModelFactoryProtocol(),
            accountAddress: ""
        )
        let view = MockStakingBalanceViewProtocol()
        presenter.view = view

        // given
        let cancelExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).cancel(from: any()).then { _ in
                cancelExpectation.fulfill()
            }
        }
        // when
        presenter.didReceive(stashItemResult: .success(nil))

        // then
        wait(for: [cancelExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
