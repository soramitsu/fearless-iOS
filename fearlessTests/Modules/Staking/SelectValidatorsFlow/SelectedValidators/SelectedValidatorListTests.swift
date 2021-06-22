import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils
import SoraFoundation

class SelectedValidatorListTests: XCTestCase {
    func testSetup() {
        // given

        let view = MockSelectedValidatorListViewProtocol()
        let wireframe = MockSelectedValidatorListWireframeProtocol()
        let viewModelFactory = SelectedValidatorListViewModelFactory()

        let validators = CustomValidatorListTestDataGenerator.goodValidators

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedValidators: validators,
            maxTargets: 16)

        presenter.view = view

        // when

        let reloadExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didRemoveItem(at: any()).thenDoNothing()

            when(stub).reload(any()).then { viewModel in
                XCTAssertEqual(viewModel.cellViewModels.count, validators.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        // then

        wait(
            for: [reloadExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }
}
