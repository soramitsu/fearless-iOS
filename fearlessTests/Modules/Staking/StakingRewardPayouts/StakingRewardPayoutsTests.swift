import XCTest
import Cuckoo
import RobinHood
import SoraFoundation
@testable import fearless

class StakingRewardPayoutsTests: XCTestCase {

    func testViewStateIsLoadingThenError() {
        let payoutServiceThatReturnsError = PayoutRewardsServiceStub.error()
        let eraCountdownOperationFactory = MockEraCountdownOperationFactoryProtocol()
        let runtimeService = try! RuntimeCodingServiceStub.createWestendService()

        let connection = MockJSONRPCEngine()

        let interactor = StakingRewardPayoutsInteractor(
            singleValueProviderFactory: SingleValueProviderFactoryStub.westendNominatorStub(),
            payoutService: payoutServiceThatReturnsError,
            assetId: WalletAssetId.westend,
            chain: .westend,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            operationManager: OperationManager(),
            runtimeService: runtimeService,
            connection: connection
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

        stub(eraCountdownOperationFactory) { stub in
            when(stub).fetchCountdownOperationWrapper(connection: any(), runtimeCodingService: any()).then { _ in
                CompoundOperationWrapper.createWithResult(
                    EraCountdown(
                        activeEra: 0,
                        eraLength: 0,
                        sessionLength: 0,
                        eraStartSessionIndex: 0,
                        currentSessionIndex: 0,
                        currentSlot: 0,
                        genesisSlot: 0,
                        blockCreationTime: 0,
                        createdAtDate: Date()
                    )
                )
            }
        }

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

    func testHandlePresenterActions() {
        // given
        let interactor = MockStakingRewardPayoutsInteractorInputProtocol()
        let wireframe = MockStakingRewardPayoutsWireframeProtocol()
        let view = MockStakingRewardPayoutsViewProtocol()

        let viewModelFactory = MockStakingPayoutViewModelFactoryProtocol()
        let presenter = StakingRewardPayoutsPresenter(
            chain: .westend,
            viewModelFactory: viewModelFactory
        )
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        presenter.view = view

        stub(interactor) { stub in
            when(stub).setup().then {
                if case let Result.success(payoutsInfo) = PayoutRewardsServiceStub.dummy().result {
                    presenter.didReceive(result: .success(payoutsInfo))
                }
            }
        }

        stub(viewModelFactory) { stub in
            when(stub).createPayoutsViewModel(payoutsInfo: any(), priceData: any(), eraCompletionTime: any()).then { _ in
                LocalizableResource { _ in
                    StakingPayoutViewModel(
                        cellViewModels: [],
                        eraComletionTime: nil,
                        bottomButtonTitle: ""
                    )
                }
            }
        }

        let viewStateIsPayoutListExpectation = XCTestExpectation()
        stub(view) { stub in
            when(stub).reload(with: any()).then { viewState in
                if case StakingRewardPayoutsViewState.payoutsList(_) = viewState {
                    viewStateIsPayoutListExpectation.fulfill()
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

        let showPayoutConfirmationExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub)
                .showPayoutConfirmation(for: any(), from: any())
                .then { _ in
                    showPayoutConfirmationExpectation.fulfill()
                }
        }

        // when
        presenter.setup()
        presenter.handleSelectedHistory(at: 0)
        presenter.handlePayoutAction()

        // then
        wait(
            for: [
                viewStateIsPayoutListExpectation,
                showRewardDetailsExpectation,
                showPayoutConfirmationExpectation
            ],
            timeout: Constants.defaultExpectationDuration
        )
    }
}
