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

        let generator = CustomValidatorListTestDataGenerator.self

        let selectedvalidatorList = generator.createSelectedValidators(
            from: generator.goodValidators
        )

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedValidatorList: selectedvalidatorList,
            maxTargets: 16)

        presenter.view = view

        // when

        let reloadExpectation = XCTestExpectation()
        let removeLastExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReload(any()).then { viewModel in
                XCTAssertEqual(viewModel.cellViewModels.count, selectedvalidatorList.count)
                reloadExpectation.fulfill()
            }
        }

        presenter.setup()

        stub(view) { stub in
            when(stub).didChangeViewModel(
                any(),
                byRemovingItemAt: any()
            ).then { viewModel, index in
                XCTAssertEqual(index, viewModel.cellViewModels.count)
                removeLastExpectation.fulfill()
            }
        }

        presenter.removeItem(at: selectedvalidatorList.count - 1)

        // then

        wait(
            for: [reloadExpectation, removeLastExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }
}
