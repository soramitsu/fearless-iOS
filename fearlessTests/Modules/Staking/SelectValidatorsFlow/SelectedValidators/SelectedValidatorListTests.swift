import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils
import SoraFoundation

class SelectedValidatorListTests: XCTestCase {
    private func createSelectedValidators(from validators: [ElectedValidatorInfo]) -> [SelectedValidatorInfo] {
        validators.map {
            SelectedValidatorInfo(
                address: $0.address,
                identity: $0.identity,
                stakeInfo: ValidatorStakeInfo(
                    nominators: $0.nominators,
                    totalStake: $0.totalStake,
                    stakeReturn: $0.stakeReturn,
                    maxNominatorsRewarded: $0.maxNominatorsRewarded
                ),
                commission: $0.comission,
                hasSlashes: $0.hasSlashes
            )
        }
    }

    func testSetup() {
        // given

        let view = MockSelectedValidatorListViewProtocol()
        let wireframe = MockSelectedValidatorListWireframeProtocol()
        let viewModelFactory = SelectedValidatorListViewModelFactory()

        let selectedvalidatorList = createSelectedValidators(
            from: CustomValidatorListTestDataGenerator.goodValidators
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
