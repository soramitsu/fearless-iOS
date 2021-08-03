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

        let generator = CustomValidatorListTestDataGenerator.self

        let selectedValidatorList = generator
            .createSelectedValidators(from: [generator.goodValidator])

        let fullValidatorList = generator
            .createSelectedValidators(from: generator.goodValidators)


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
                XCTAssertEqual(viewModel.cellViewModels.count, fullValidatorList.count)
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
