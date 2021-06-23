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
        let removeExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReload(any()).then { viewModel in
                XCTAssertEqual(viewModel.cellViewModels.count, validators.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        stub(view) { stub in
            when(stub).didChangeViewModel(
                any(),
                byRemovingItemAt: any()
            ).then { viewModel, index in
                XCTAssertLessThan(index, viewModel.cellViewModels.count)
                removeExpectation.fulfill()
            }
        }

        presenter.removeItem(at: validators.count - 1)

        // then

        wait(
            for: [reloadExpectation, removeExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }
}
