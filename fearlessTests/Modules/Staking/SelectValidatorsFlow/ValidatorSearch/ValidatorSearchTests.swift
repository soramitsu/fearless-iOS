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

        let interactor = ValidatorSearchInteractor()

        let validators = CustomValidatorListTestDataGenerator.goodValidators
        let selectedValidator = CustomValidatorListTestDataGenerator.goodValidator

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            allValidators: validators,
            selectedValidators: [selectedValidator],
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
