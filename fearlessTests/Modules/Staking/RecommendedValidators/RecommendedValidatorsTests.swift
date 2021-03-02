import XCTest
@testable import fearless
import Cuckoo
import RobinHood

class RecommendedValidatorsTests: XCTestCase {
    let nominationState = StartStakingResult(amount: 1.0,
                                             rewardDestination: .restake)

    let recommended: [ElectedValidatorInfo] = {
        let address = "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6"
        let validator = ElectedValidatorInfo(address: address,
                                             nominators: [],
                                             totalStake: 10.0,
                                             ownStake: 10.0,
                                             comission: 0.1,
                                             identity: AccountIdentity(name: "Test"),
                                             stakeReturnPer: 10.0,
                                             hasSlashes: false,
                                             oversubscribed: false)
        return [validator]
    }()

    let others: [ElectedValidatorInfo] = {
        let address = "5DnQFjSrJUiCnDb9mrbbCkGRXwKZc5v31M261PMMTTMFDawq"
        let validator = ElectedValidatorInfo(address: address,
                                             nominators: [],
                                             totalStake: 5.0,
                                             ownStake: 5.0,
                                             comission: 0.1,
                                             identity: nil,
                                             stakeReturnPer: 10.0,
                                             hasSlashes: false,
                                             oversubscribed: true)
        return [validator]
    }()

    var all: [ElectedValidatorInfo] { others + recommended }

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
                CompoundOperationWrapper.createWithResult(self.all)
            }
        }

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(viewModel: any()).then { _ in
                setupExpectation.fulfill()
            }
        }

        stub(wireframe) { stub in
            when(stub).proceed(from: any(), result: any()).then { (_, nomination) in
                XCTAssertEqual(Set(self.recommended.map({ $0.address })),
                               Set(nomination.targets.map({ $0.address })))
            }

            when(stub).showCustom(from: any(), validators: any()).then { (_ , validators) in
                XCTAssertEqual(self.all, validators)
            }

            when(stub).showRecommended(from: any(), validators: any()).then { (_, validators) in
                XCTAssertEqual(self.recommended, validators)
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
