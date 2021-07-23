import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import fearless

class StakingBalanceTests: XCTestCase {

    func testStakingBalanceActionsOnSuccess() {
        let interactor = MockStakingBalanceInteractorInputProtocol()
        let wireframe = MockStakingBalanceWireframeProtocol()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: MockStakingBalanceViewModelFactoryProtocol(),
            dataValidatingFactory: dataValidatingFactory,
            accountAddress: "",
            countdownTimer: CountdownTimer()
        )
        let view = MockStakingBalanceViewProtocol()
        presenter.view = view
        dataValidatingFactory.view = view

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
        presenter.stakingLedger = WestendStub.ledgerInfo.item

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
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: MockStakingBalanceViewModelFactoryProtocol(),
            dataValidatingFactory: dataValidatingFactory,
            accountAddress: "",
            countdownTimer: CountdownTimer()
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

        let actionClosure: (StakingBalancePresenterProtocol) -> Void = { $0.handleAction(.bondMore) }

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: nil,
            controller: nil,
            ledger: nil
        )

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: nil,
            controller: stubAccount,
            ledger: nil
        )
    }

    func testUnbondActionOnError() {
        let stubAccount = AccountItem(address: "", cryptoType: .ecdsa, username: "", publicKeyData: Data())

        let actionClosure: (StakingBalancePresenterProtocol) -> Void = { $0.handleAction(.unbond) }

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: nil,
            controller: nil,
            ledger: nil
        )

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: stubAccount,
            controller: nil,
            ledger: nil
        )

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: stubAccount,
            controller: stubAccount,
            ledger: nil
        )
    }

    func testRedeemActionOnError() {
        let stubAccount = AccountItem(address: "", cryptoType: .ecdsa, username: "", publicKeyData: Data())

        let actionClosure: (StakingBalancePresenterProtocol) -> Void = { $0.handleAction(.redeem) }

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: nil,
            controller: nil,
            ledger: nil
        )

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: stubAccount,
            controller: nil,
            ledger: nil
        )
    }

    func testRebondActionOnError() {
        let stubAccount = AccountItem(address: "", cryptoType: .ecdsa, username: "", publicKeyData: Data())

        let actionClosure: (StakingBalancePresenterProtocol) -> Void = { $0.handleUnbondingMoreAction() }

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: nil,
            controller: nil,
            ledger: nil
        )

        performTestStakingBalanceActionsOnError(
            for: actionClosure,
            stash: stubAccount,
            controller: nil,
            ledger: nil
        )
    }

    private func performTestStakingBalanceActionsOnError(
        for actionClosure: (StakingBalancePresenterProtocol) -> Void,
        stash: AccountItem?,
        controller: AccountItem?,
        ledger: StakingLedger?
    ) {
        let interactor = MockStakingBalanceInteractorInputProtocol()
        let wireframe = MockStakingBalanceWireframeProtocol()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: MockStakingBalanceViewModelFactoryProtocol(),
            dataValidatingFactory: dataValidatingFactory,
            accountAddress: "",
            countdownTimer: CountdownTimer()
        )
        let view = MockStakingBalanceViewProtocol()
        presenter.view = view
        dataValidatingFactory.view = view

        stub(view) { stub in
            when(stub).localizationManager.get.then { _ in nil }
        }

        // given

        let presentErrorAlertExpectation = XCTestExpectation()
        presenter.controllerAccount = controller
        presenter.stashAccount = stash
        presenter.stakingLedger = ledger

        stub(wireframe) { stub in
            when(stub)
                .present(message: any(), title: any(), closeAction: any(), from: any())
                .then { _ in
                    presentErrorAlertExpectation.fulfill()
                }
        }

        // when

        actionClosure(presenter)

        // then
        wait(for: [presentErrorAlertExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
