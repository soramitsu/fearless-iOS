import XCTest
@testable import fearless
import Cuckoo
import RobinHood

class RecommendedValidatorsTests: XCTestCase {
    let nominationState = StartStakingResult(amount: 1.0,
                                             rewardDestination: .restake)

    func testSetupAndOptionSelect() {
        // given

        let view = MockRecommendedValidatorsViewProtocol()
        let wireframe = MockRecommendedValidatorsWireframeProtocol()
        let operationFactory = MockValidatorOperationFactorProtocol()

        let presenter = RecommendedValidatorsPresenter(state: nominationState)
        let interactor = RecommendedValidatorsInteractor(operationFactory: operationFactory,
                                                         operationManager: OperationManager())

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        stub(operationFactory) { stub in
            when(stub).allElectedOperation().then { _ in
                CompoundOperationWrapper.createWithResult(WestendStub.allValidators)
            }
        }

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModel: any()).then { _ in
                setupExpectation.fulfill()
            }
        }

        let recommended = WestendStub.recommendedValidators
        let all = WestendStub.allValidators

        stub(wireframe) { stub in
            when(stub).proceed(from: any(), result: any()).then { (_, nomination) in
                XCTAssertEqual(Set(recommended.map({ $0.address })),
                               Set(nomination.targets.map({ $0.address })))
            }

            when(stub).showCustom(from: any(), validators: any()).then { (_ , validators) in
                XCTAssertEqual(all, validators)
            }

            when(stub).showRecommended(from: any(), validators: any()).then { (_, validators) in
                XCTAssertEqual(recommended, validators)
            }
        }

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        presenter.selectRecommendedValidators()
        presenter.selectCustomValidators()
        presenter.proceed()

        verify(wireframe, times(1)).showCustom(from: any(), validators: any())
        verify(wireframe, times(1)).showRecommended(from: any(), validators: any())
        verify(wireframe, times(1)).proceed(from: any(), result: any())
    }
}
