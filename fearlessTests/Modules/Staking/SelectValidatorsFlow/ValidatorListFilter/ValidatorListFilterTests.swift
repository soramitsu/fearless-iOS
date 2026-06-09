import FearlessFoundation
import UIKit
import XCTest
@testable import fearless

final class ValidatorListFilterTests: XCTestCase {
    func testRelaychainSetup_thenShowsInitialRecommendedFilter() {
        let fixture = makeRelaychainFixture(filter: .recommendedFilter())

        fixture.presenter.setup()

        XCTAssertFalse(fixture.view.lastViewModel?.canApply ?? true)
        XCTAssertFalse(fixture.view.lastViewModel?.canReset ?? true)
        XCTAssertEqual(fixture.view.lastViewModel?.filterModel?.cellViewModels.count, 4)
        XCTAssertEqual(fixture.view.lastViewModel?.sortModel.cellViewModels.count, 3)
        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
    }

    func testRelaychainToggleFilter_thenUpdatesStateAndViewModel() {
        let fixture = makeRelaychainFixture(filter: .recommendedFilter())
        fixture.presenter.setup()

        fixture.presenter.toggleFilterItem(at: ValidatorListRelaychainFilterRow.slashed.rawValue)

        XCTAssertTrue(fixture.state.currentFilter.allowsSlashed)
        XCTAssertTrue(fixture.view.lastViewModel?.canApply ?? false)
        XCTAssertTrue(fixture.view.lastViewModel?.canReset ?? false)
    }

    func testRelaychainSelectSort_thenUpdatesSortCriterion() {
        let fixture = makeRelaychainFixture(filter: .recommendedFilter())
        fixture.presenter.setup()

        fixture.presenter.selectFilterItem(at: ValidatorListRelaychainSortRow.ownStake.rawValue)

        XCTAssertEqual(fixture.state.currentFilter.sortedBy, .ownStake)
        XCTAssertTrue(fixture.view.lastViewModel?.canApply ?? false)
    }

    func testResetFilter_thenRestoresRecommendedFilter() {
        let fixture = makeRelaychainFixture(filter: .recommendedFilter())
        fixture.presenter.setup()
        fixture.presenter.toggleFilterItem(at: ValidatorListRelaychainFilterRow.slashed.rawValue)

        fixture.presenter.resetFilter()

        XCTAssertEqual(fixture.state.currentFilter, .recommendedFilter())
        XCTAssertFalse(fixture.view.lastViewModel?.canApply ?? true)
        XCTAssertFalse(fixture.view.lastViewModel?.canReset ?? true)
    }

    func testApplyFilter_thenNotifiesDelegateAndCloses() {
        let fixture = makeRelaychainFixture(filter: .recommendedFilter())
        fixture.presenter.toggleFilterItem(at: ValidatorListRelaychainFilterRow.slashed.rawValue)

        fixture.presenter.applyFilter()

        guard case let .relaychain(filter)? = fixture.delegate.flow else {
            XCTFail("Expected relaychain filter flow")
            return
        }

        XCTAssertEqual(filter, fixture.state.currentFilter)
        XCTAssertTrue(fixture.wireframe.didClose)
    }

    func testParachainSetup_thenShowsSortOnlyFilterViewModel() {
        let fixture = makeParachainFixture(filter: .recommendedFilter())

        fixture.presenter.setup()

        XCTAssertNil(fixture.view.lastViewModel?.filterModel)
        XCTAssertEqual(fixture.view.lastViewModel?.sortModel.cellViewModels.count, 5)
        XCTAssertFalse(fixture.view.lastViewModel?.canApply ?? true)
        XCTAssertFalse(fixture.view.lastViewModel?.canReset ?? true)
    }

    func testParachainSelectSort_thenAppliesParachainCriterion() {
        let fixture = makeParachainFixture(filter: .recommendedFilter())
        fixture.presenter.setup()

        fixture.presenter.selectFilterItem(at: ValidatorListParachainSortRow.minimumBond.rawValue)

        XCTAssertEqual(fixture.state.currentFilter.sortedBy, .minimumBond)
        XCTAssertTrue(fixture.view.lastViewModel?.canApply ?? false)
    }

    private func makeRelaychainFixture(
        filter: CustomValidatorRelaychainListFilter
    ) -> ValidatorListFilterRelaychainFixture {
        let state = ValidatorListFilterRelaychainViewModelState(filter: filter)
        let wireframe = ValidatorListFilterWireframeSpy()
        let view = ValidatorListFilterViewSpy()
        let delegate = ValidatorListFilterDelegateSpy()
        let presenter = ValidatorListFilterPresenter(
            wireframe: wireframe,
            viewModelFactory: ValidatorListFilterRelaychainViewModelFactory(),
            viewModelState: state,
            asset: makeAsset(),
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        presenter.delegate = delegate

        return ValidatorListFilterRelaychainFixture(
            presenter: presenter,
            state: state,
            wireframe: wireframe,
            view: view,
            delegate: delegate
        )
    }

    private func makeParachainFixture(
        filter: CustomValidatorParachainListFilter
    ) -> ValidatorListFilterParachainFixture {
        let state = ValidatorListFilterParachainViewModelState(filter: filter)
        let wireframe = ValidatorListFilterWireframeSpy()
        let view = ValidatorListFilterViewSpy()
        let delegate = ValidatorListFilterDelegateSpy()
        let presenter = ValidatorListFilterPresenter(
            wireframe: wireframe,
            viewModelFactory: ValidatorListFilterParachainViewModelFactory(),
            viewModelState: state,
            asset: makeAsset(),
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        presenter.delegate = delegate

        return ValidatorListFilterParachainFixture(
            presenter: presenter,
            state: state,
            wireframe: wireframe,
            view: view,
            delegate: delegate
        )
    }

    private func makeAsset() -> AssetModel {
        AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "unit",
            precision: 12,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .normal
        )
    }
}

private struct ValidatorListFilterRelaychainFixture {
    let presenter: ValidatorListFilterPresenter
    let state: ValidatorListFilterRelaychainViewModelState
    let wireframe: ValidatorListFilterWireframeSpy
    let view: ValidatorListFilterViewSpy
    let delegate: ValidatorListFilterDelegateSpy
}

private struct ValidatorListFilterParachainFixture {
    let presenter: ValidatorListFilterPresenter
    let state: ValidatorListFilterParachainViewModelState
    let wireframe: ValidatorListFilterWireframeSpy
    let view: ValidatorListFilterViewSpy
    let delegate: ValidatorListFilterDelegateSpy
}

private final class ValidatorListFilterViewSpy: ValidatorListFilterViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    private(set) var lastViewModel: ValidatorListFilterViewModel?

    func didUpdateViewModel(_ viewModel: ValidatorListFilterViewModel) {
        lastViewModel = viewModel
    }

    func applyLocalization() {}
}

private final class ValidatorListFilterWireframeSpy: ValidatorListFilterWireframeProtocol {
    private(set) var didClose = false

    func close(_: ControllerBackedProtocol?) {
        didClose = true
    }
}

private final class ValidatorListFilterDelegateSpy: ValidatorListFilterDelegate {
    private(set) var flow: ValidatorListFilterFlow?

    func didUpdate(with flow: ValidatorListFilterFlow) {
        self.flow = flow
    }
}
