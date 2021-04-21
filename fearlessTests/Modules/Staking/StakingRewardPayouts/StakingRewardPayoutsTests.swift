import XCTest
import Cuckoo
import RobinHood
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
}
