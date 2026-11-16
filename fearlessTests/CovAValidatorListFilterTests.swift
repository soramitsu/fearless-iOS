import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAFilterDelegateSpy: ValidatorListFilterDelegate {
    private(set) var flows: [ValidatorListFilterFlow] = []
    func didUpdate(with flow: ValidatorListFilterFlow) {
        flows.append(flow)
    }
}

final class CovAFilterListenerSpy: ValidatorListFilterModelStateListener {
    private(set) var changes = 0
    func modelStateDidChanged(viewModelState _: ValidatorListFilterViewModelState) {
        changes += 1
    }
}

final class CovAValidatorListFilterTests: XCTestCase {
    private let locale = CovAFixtures.locale

    func testStateTogglesEveryFilterRowAndSort() throws {
        let state = ValidatorListFilterRelaychainViewModelState(filter: .recommendedFilter())
        let listener = CovAFilterListenerSpy()
        state.setStateListener(listener)

        for row in ValidatorListRelaychainFilterRow.allCases {
            state.toggleFilterItem(at: row.rawValue)
            XCTAssertFalse(row.titleSubtitleViewModel.value(for: locale).title.isEmpty)
        }
        XCTAssertTrue(state.currentFilter.allowsNoIdentity)
        XCTAssertTrue(state.currentFilter.allowsSlashed)
        XCTAssertTrue(state.currentFilter.allowsOversubscribed)
        XCTAssertEqual(state.currentFilter.allowsClusters, .unlimited)
        state.toggleFilterItem(at: ValidatorListRelaychainFilterRow.clusterLimit.rawValue)
        XCTAssertEqual(state.currentFilter.allowsClusters, .limited(amount: StakingConstants.targetsClusterLimit))
        state.toggleFilterItem(at: 99)

        for row in ValidatorListRelaychainSortRow.allCases {
            state.selectFilterItem(at: row.rawValue)
            XCTAssertEqual(state.currentFilter.sortedBy, row.sortCriterion)
        }
        state.selectFilterItem(at: 99)
        XCTAssertEqual(listener.changes, 8)

        state.resetFilter()
        XCTAssertEqual(state.currentFilter, .recommendedFilter())
        guard case let .relaychain(filter) = try XCTUnwrap(state.validatorListFilterFlow()) else { return XCTFail("flow") }
        XCTAssertEqual(filter, .recommendedFilter())
    }

    func testFactoryReflectsApplyAndResetAvailability() throws {
        let state = ValidatorListFilterRelaychainViewModelState(filter: .recommendedFilter())
        let factory = ValidatorListFilterRelaychainViewModelFactory()
        let initial = try XCTUnwrap(factory.buildViewModel(viewModelState: state, token: "COV", locale: locale))
        XCTAssertFalse(initial.canApply)
        XCTAssertFalse(initial.canReset)
        XCTAssertEqual(initial.filterModel?.cellViewModels.count, 4)
        XCTAssertEqual(initial.sortModel.cellViewModels.count, 3)
        XCTAssertTrue(initial.sortModel.cellViewModels[0].selectable)
        XCTAssertTrue(initial.filterModel?.cellViewModels[0].selectable ?? false, "the recommended filter excludes unidentified validators")

        state.selectFilterItem(at: ValidatorListRelaychainSortRow.ownStake.rawValue)
        state.toggleFilterItem(at: 0)
        let changed = try XCTUnwrap(factory.buildViewModel(viewModelState: state, token: "COV", locale: locale))
        XCTAssertTrue(changed.canApply)
        XCTAssertTrue(changed.canReset)
        XCTAssertTrue(changed.sortModel.cellViewModels[2].selectable)
        XCTAssertFalse(changed.filterModel?.cellViewModels[0].selectable ?? true)
        let titles = changed.sortModel.cellViewModels.map(\.underlyingViewModel.title)
        XCTAssertEqual(Set(titles).count, 3)
    }

    func testFactoryBuiltModuleRendersAndAppliesFilter() throws {
        let delegate = CovAFilterDelegateSpy()
        let view = try XCTUnwrap(ValidatorListFilterViewFactory.createView(
            asset: CovAFixtures.asset(),
            flow: .relaychain(filter: .recommendedFilter()),
            delegate: delegate
        ))
        let controller = try XCTUnwrap(view.controller as? ValidatorListFilterViewController)
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.pushViewController(controller, animated: false)
        let window = CovAViewInspector.host(navigation)
        controller.loadViewIfNeeded()
        let table = controller.rootView.tableView
        table.layoutIfNeeded()

        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 4)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 1), 3)
        XCTAssertFalse(controller.rootView.applyButton.isEnabled)
        for section in 0 ..< 2 {
            XCTAssertNotNil(controller.tableView(table, viewForHeaderInSection: section))
            XCTAssertGreaterThan(controller.tableView(table, heightForHeaderInSection: section), 0)
            XCTAssertNotNil(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: section)))
        }
        _ = controller.tableView(table, heightForFooterInSection: 0)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 1))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(controller.rootView.applyButton.isEnabled)
        if let switchCell = table.visibleCells.compactMap({ $0 as? SwitchTableViewCell }).first {
            controller.didToggle(cell: switchCell)
        }

        controller.didTapResetButton()
        XCTAssertFalse(controller.rootView.applyButton.isEnabled)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 2, section: 1))
        controller.didTapApplyButton()
        guard case let .relaychain(applied) = try XCTUnwrap(delegate.flows.last) else { return XCTFail("delegate flow") }
        XCTAssertEqual(applied.sortedBy, .ownStake)
        controller.applyLocalization()
        XCTAssertEqual(
            controller.title,
            R.string.localizable.walletFiltersTitle(preferredLanguages: controller.localizationManager?.selectedLocale.rLanguages)
        )
        window.isHidden = true
    }

    func testFilterViewModelSectionTitlesUseToken() throws {
        let state = ValidatorListFilterRelaychainViewModelState(filter: .defaultFilter())
        let viewModel = try XCTUnwrap(ValidatorListFilterRelaychainViewModelFactory().buildViewModel(
            viewModelState: state,
            token: "KSM",
            locale: locale
        ))
        XCTAssertFalse(viewModel.sortModel.title.isEmpty)
        XCTAssertTrue(viewModel.canReset)
        let joined = viewModel.sortModel.cellViewModels.map(\.underlyingViewModel.title).joined(separator: " ")
        XCTAssertFalse(joined.isEmpty)
    }
}
