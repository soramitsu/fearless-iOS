import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils
import SoraFoundation

class ValidatorSearchTests: XCTestCase {
    func testSetup() {
        // given

        let view = MockValidatorSearchViewProtocol()
        let wireframe = MockValidatorSearchWireframeProtocol()
        let viewModelFactory = ValidatorSearchViewModelFactory()
        let validatorOperationFactory = ValidatorOperationFactoryProtocolStub()

        let interactor = ValidatorSearchInteractor(
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager
        )

        let validators = CustomValidatorListTestDataGenerator.goodValidators
        let selectedValidatorList = [CustomValidatorListTestDataGenerator.goodValidator].map {
            SelectedValidatorInfo(
                address: $0.address,
                identity: $0.identity,
                stakeInfo: ValidatorStakeInfo(
                    nominators: $0.nominators,
                    totalStake: $0.totalStake,
                    stakeReturn: $0.stakeReturn,
                    maxNominatorsRewarded: $0.maxNominatorsRewarded
                )
            )
        }

        let fullValidatorList = validators.map {
            SelectedValidatorInfo(
                address: $0.address,
                identity: $0.identity,
                stakeInfo: ValidatorStakeInfo(
                    nominators: $0.nominators,
                    totalStake: $0.totalStake,
                    stakeReturn: $0.stakeReturn,
                    maxNominatorsRewarded: $0.maxNominatorsRewarded
                )
            )
        }


        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            fullValidatorList: fullValidatorList,
            selectedValidatorList: selectedValidatorList,
            localizationManager: LocalizationManager.shared)

        presenter.view = view

        // when

        let reloadExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReset().thenDoNothing()
            
            when(stub).didReload(any()).then { viewModel in
                XCTAssertEqual(viewModel.cellViewModels.count, validators.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()
        presenter.search(for: "val")

        // then

        wait(
            for: [reloadExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }
}
