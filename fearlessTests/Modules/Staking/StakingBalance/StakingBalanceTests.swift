import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import fearless

class StakingBalanceTests: XCTestCase {

    func testStakingBalanceActionsOnSuccess() {
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

        let stubAccount = AccountItem(address: "", cryptoType: .ecdsa, username: "", publicKeyData: Data())
        presenter.stashAccount = stubAccount

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
        presenter.controllerAccount = stubAccount

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


        // given
        let showRebondActionSheetExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub).present(viewModel: any(), style: any(), from: any()).then { _ in
                showRebondActionSheetExpectation.fulfill()
            }
        }
        // when
        presenter.handleUnbondingMoreAction()

        // then
        wait(for: [showRebondActionSheetExpectation], timeout: Constants.defaultExpectationDuration)
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

    func testBondActionOnError() {
        let stubAccount = AccountItem(address: "", cryptoType: .ecdsa, username: "", publicKeyData: Data())

        performTestStakingBalanceActionsOnError(
            for: .bondMore,
            stash: nil,
            controller: nil
        )

        performTestStakingBalanceActionsOnError(
            for: .bondMore,
            stash: nil,
            controller: stubAccount
        )
    }

    func testUnbondActionOnError() {
        let stubAccount = AccountItem(address: "", cryptoType: .ecdsa, username: "", publicKeyData: Data())

        performTestStakingBalanceActionsOnError(
            for: .unbond,
            stash: nil,
            controller: nil
        )

        performTestStakingBalanceActionsOnError(
            for: .unbond,
            stash: stubAccount,
            controller: nil
        )
    }

    func testRedeemActionOnError() {
        let stubAccount = AccountItem(address: "", cryptoType: .ecdsa, username: "", publicKeyData: Data())

        performTestStakingBalanceActionsOnError(
            for: .redeem,
            stash: nil,
            controller: nil
        )

        performTestStakingBalanceActionsOnError(
            for: .redeem,
            stash: stubAccount,
            controller: nil
        )
    }

    private func performTestStakingBalanceActionsOnError(
        for action: StakingBalanceAction,
        stash: AccountItem?,
        controller: AccountItem?
    ) {
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
        presenter.controllerAccount = controller
        presenter.stashAccount = stash

        stub(wireframe) { stub in
            when(stub)
                .present(message: any(), title: any(), closeAction: any(), from: any())
                .then { _ in
                    presentErrorAlertExpectation.fulfill()
                }
        }

        // when

        presenter.handleAction(action)

        // then
        wait(for: [presentErrorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
