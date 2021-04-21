import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import fearless

class StakingRewardPayoutsTests: XCTestCase {

    func testViewStateIsLoadingThenError() {
        let payoutServiceThatReturnsError = PayoutRewardsServiceStub.error()
        let interactor = StakingRewardPayoutsInteractor(
            payoutService: payoutServiceThatReturnsError,
            priceProvider: SingleValueProviderFactoryStub.westendNominatorStub().price,
            operationManager: OperationManager()
        )
        let view = MockStakingRewardPayoutsViewProtocol()

        let viewModelFactory = MockStakingPayoutViewModelFactoryProtocol()
        let presenter = StakingRewardPayoutsPresenter(
            chain: .westend,
            viewModelFactory: viewModelFactory
        )
        presenter.interactor = interactor
        presenter.view = view
        interactor.presenter = presenter

        // given
        let viewStateIsLoadingOnPresenterSetup = XCTestExpectation()
        let viewStateIsNotLoadingWhenPresenterRecievedResult = XCTestExpectation()
        let viewStateIsErrorWhenPresenterRecievedError = XCTestExpectation()

        stub(view) { stub in
            when(stub).reload(with: any())
                .then { viewState in
                    if case let StakingRewardPayoutsViewState.loading(loading) = viewState, loading {
                        viewStateIsLoadingOnPresenterSetup.fulfill()
                    }
                }
                .then { viewState in
                    if case let StakingRewardPayoutsViewState.loading(loading) = viewState, !loading {
                        viewStateIsNotLoadingWhenPresenterRecievedResult.fulfill()
                    }
                }.then { viewState in
                    if case StakingRewardPayoutsViewState.error(_) = viewState {
                        viewStateIsErrorWhenPresenterRecievedError.fulfill()
                    }
                }
        }

        // when
        presenter.setup()

        // then
        wait(
            for: [
                viewStateIsLoadingOnPresenterSetup,
                viewStateIsNotLoadingWhenPresenterRecievedResult,
                viewStateIsErrorWhenPresenterRecievedError
            ],
            timeout: Constants.defaultExpectationDuration
        )
        verify(view, times(3)).reload(with: any())
        XCTAssert(payoutServiceThatReturnsError.fetchPayoutsCounter == 1)
    }

    func testShowRewardDetailsWhenUserSelectTableRow() {
        // given
        let interactor = MockStakingRewardPayoutsInteractorInputProtocol()
        let wireframe = MockStakingRewardPayoutsWireframeProtocol()

        let viewModelFactory = MockStakingPayoutViewModelFactoryProtocol()
        let presenter = StakingRewardPayoutsPresenter(
            chain: .westend,
            viewModelFactory: viewModelFactory
        )
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        let viewController = StakingRewardPayoutsViewController(presenter: presenter, localizationManager: nil)
        presenter.view = viewController

        stub(interactor) { stub in
            when(stub).setup().then {
                if case let Result.success(payoutsInfo) = PayoutRewardsServiceStub.dummy().result {
                    presenter.didReceive(result: .success(payoutsInfo))
                }
            }
        }

        stub(viewModelFactory) { stub in
            when(stub).createPayoutsViewModel(payoutsInfo: any(), priceData: any()).then { _ in
                LocalizableResource { _ in
                    StakingPayoutViewModel(
                        cellViewModels: [],
                        bottomButtonTitle: ""
                    )
                }
            }
        }

        let showRewardDetailsExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub)
                .showRewardDetails(from: any(), payoutInfo: any(), activeEra: any(), historyDepth: any(), chain: any())
                .then { _ in
                    showRewardDetailsExpectation.fulfill()
                }
        }

        // when
        let tableView = viewController.rootView.tableView
        viewController.loadView()
        tableView.delegate?.tableView?(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))

        // then
        wait(for: [showRewardDetailsExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testShowPayoutConfirmationWhenUserTapsPayoutButton() {
        // given
        let interactor = MockStakingRewardPayoutsInteractorInputProtocol()
        let wireframe = MockStakingRewardPayoutsWireframeProtocol()

        let viewModelFactory = MockStakingPayoutViewModelFactoryProtocol()
        let presenter = StakingRewardPayoutsPresenter(
            chain: .westend,
            viewModelFactory: viewModelFactory
        )
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        let viewController = StakingRewardPayoutsViewController(presenter: presenter, localizationManager: nil)
        presenter.view = viewController

        stub(interactor) { stub in
            when(stub).setup().then {
                if case let Result.success(payoutsInfo) = PayoutRewardsServiceStub.dummy().result {
                    presenter.didReceive(result: .success(payoutsInfo))
                }
            }
        }

        stub(viewModelFactory) { stub in
            when(stub).createPayoutsViewModel(payoutsInfo: any(), priceData: any()).then { _ in
                LocalizableResource { _ in
                    StakingPayoutViewModel(
                        cellViewModels: [],
                        bottomButtonTitle: "Payout all"
                    )
                }
            }
        }

        let showPayoutConfirmationExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub)
                .showPayoutConfirmation(for: any(), from: any())
                .then { _ in
                    showPayoutConfirmationExpectation.fulfill()
                }
        }

        // when
        let payoutButton = viewController.rootView.payoutButton
        payoutButton.sendActions(for: .touchUpInside)

        // then
        wait(for: [showPayoutConfirmationExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
