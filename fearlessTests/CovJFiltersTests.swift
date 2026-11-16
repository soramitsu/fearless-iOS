import XCTest
import UIKit
import SoraFoundation
@testable import fearless

final class CovJFiltersOutput: FiltersModuleOutput {
    var finished: [[FilterSet]] = []
    func didFinishWithFilters(filters: [FilterSet]) { finished.append(filters) }
}

final class CovJFiltersTests: XCTestCase {
    private func historyFilters() -> [FilterSet] {
        [
            FilterSet(title: "Type", items: [
                WalletTransactionHistoryFilter(type: .transfer, selected: true),
                WalletTransactionHistoryFilter(type: .reward, selected: false)
            ]),
            FilterSet(title: nil, items: [WalletTransactionHistoryFilter(type: .other, selected: false)])
        ]
    }

    private func selectedIds(_ filters: [FilterSet]?) -> [String] {
        (filters ?? []).flatMap(\.items).compactMap { item in
            if let item = item as? SwitchFilterItem, item.selected { return item.id }
            if let item = item as? AssetNetworksSort, item.selected { return item.id }
            return nil
        }
    }

    func testSwitchFiltersRenderToggleResetAndApply() throws {
        let output = CovJFiltersOutput()
        let view = try XCTUnwrap(FiltersViewFactory.createView(title: "Filters", filters: historyFilters(), moduleOutput: output))
        let controller = try XCTUnwrap(view.controller as? FiltersViewController)
        XCTAssertEqual(controller.modalPresentationStyle, .custom)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let layout = try XCTUnwrap(controller.view as? FiltersViewLayout)
        let table = layout.tableView
        XCTAssertFalse(table.isHidden)
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 1), 1)
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 0), 40)
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 1), 0)
        let header = try XCTUnwrap(controller.tableView(table, viewForHeaderInSection: 0) as? FilterSectionHeaderView)
        XCTAssertEqual(header.titleLabel.text, "Type")
        XCTAssertNil(controller.tableView(table, viewForHeaderInSection: 1))
        XCTAssertEqual(layout.resetButton.title(for: .normal), R.string.localizable.commonReset(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages))

        let transfer = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? SwitchFilterTableCell)
        XCTAssertEqual(transfer.filterTitleLabel.text, WalletTransactionHistoryFilter.HistoryFilterType.transfer.title)
        XCTAssertTrue(transfer.filterValueSwitch.isOn)
        let other = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 1)) as? SwitchFilterTableCell)
        XCTAssertFalse(other.filterValueSwitch.isOn)

        transfer.filterValueSwitch.isOn = false
        transfer.filterValueSwitch.sendActions(for: .valueChanged)
        XCTAssertFalse(layout.applyButton.isEnabled, "no filter left selected")
        other.filterValueSwitch.isOn = true
        other.filterValueSwitch.sendActions(for: .valueChanged)
        XCTAssertTrue(layout.applyButton.isEnabled)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 1))
        transfer.prepareForReuse()
        XCTAssertNil(transfer.delegate)

        layout.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(selectedIds(output.finished.last), ["extrinsic"])

        layout.resetButton.sendActions(for: .touchUpInside)
        layout.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(selectedIds(output.finished.last), ["transfer", "reward", "extrinsic"], "reset selects every history filter")
        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.finished.count, 2)
    }

    func testSortSelectionFinishesImmediatelyInSingleSelectionMode() throws {
        let output = CovJFiltersOutput()
        let filters = [FilterSet(title: "Sort by", items: AssetNetworksSort.defaultFilters(selected: .fiat))]
        let view = try XCTUnwrap(FiltersViewFactory.createView(filters: filters, mode: .singleSelection, moduleOutput: output))
        let controller = try XCTUnwrap(view.controller as? FiltersViewController)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let table = try XCTUnwrap(controller.view as? FiltersViewLayout).tableView
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)
        let fiat = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? SortTableCell)
        XCTAssertFalse(fiat.selectedIndicatorImageView.isHidden)
        XCTAssertEqual(fiat.filterTitleLabel.text, AssetNetworksSortType.fiat.title)
        let popularity = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? SortTableCell)
        XCTAssertTrue(popularity.selectedIndicatorImageView.isHidden)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(selectedIds(output.finished.last), ["popularity"])
        let updated = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? SortTableCell)
        XCTAssertFalse(updated.selectedIndicatorImageView.isHidden)
    }

    func testEmptyAndLoadingStatesHideTable() throws {
        let presenter = CovJFiltersPresenterSpy()
        let controller = FiltersViewController(screenTitle: nil, presenter: presenter)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        XCTAssertEqual(presenter.setups, 1)
        let table = try XCTUnwrap(controller.view as? FiltersViewLayout).tableView
        controller.didReceive(state: .loading)
        XCTAssertTrue(table.isHidden)
        XCTAssertEqual(controller.numberOfSections(in: table), 0)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 0), 0)
        XCTAssertNil(controller.tableView(table, viewForHeaderInSection: 0))
        XCTAssertFalse(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) is SortTableCell)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        controller.didReceive(state: .empty)
        XCTAssertTrue(table.isHidden)
        controller.didReceive(locale: Locale(identifier: "en_US"))
        controller.didReceive(applyEnabled: false)
        XCTAssertFalse(try XCTUnwrap(controller.view as? FiltersViewLayout).applyButton.isEnabled)
        XCTAssertTrue(presenter.sorts.isEmpty)
    }

    func testInteractorAndPresenterUpdateViewModelThroughOutputs() {
        let interactor = FiltersInteractor(filters: historyFilters(), mode: .multiSelection)
        let output = CovJFiltersInteractorOutput()
        interactor.presenter = output
        interactor.setup()
        XCTAssertEqual(selectedIds(output.received.last), ["transfer"])
        var valid: [Bool] = []
        interactor.switchFilterState(id: "reward", selected: true) { valid.append($0) }
        interactor.switchFilterState(id: "transfer", selected: false) { valid.append($0) }
        interactor.switchFilterState(id: "reward", selected: false) { valid.append($0) }
        XCTAssertEqual(valid, [true, true, false])
        interactor.applyFilters()
        XCTAssertEqual(selectedIds(output.finished.last), [])
        interactor.resetFilters()
        XCTAssertEqual(output.received.count, 2)
        XCTAssertEqual(selectedIds(output.received.last), ["transfer", "reward", "extrinsic"])

        let model = FiltersViewModelFactory().buildViewModel(from: historyFilters() + [FilterSet(title: "Sort", items: AssetNetworksSort.defaultFilters(selected: .name))],
                                                            delegate: nil, mode: .multiSelection)
        XCTAssertEqual(model.sections.map(\.items.count), [2, 1, 3])
        XCTAssertEqual((model.sections[2].items[2] as? SortFilterCellViewModel)?.selected, true)
        XCTAssertEqual((model.sections[0].items[0] as? SwitchFilterTableCellViewModel)?.enabled, true)
    }
}

final class CovJFiltersPresenterSpy: FiltersPresenterProtocol {
    var setups = 0
    var sorts: [String] = []
    func setup() { setups += 1 }
    func didTapResetButton() {}
    func didTapApplyButton() {}
    func didTapCloseButton() {}
    func didSelectSort(viewModel: SortFilterCellViewModel) { sorts.append(viewModel.id) }
}

final class CovJFiltersInteractorOutput: FiltersInteractorOutputProtocol {
    var received: [[FilterSet]] = []
    var finished: [[FilterSet]] = []
    func didReceive(filters: [FilterSet]) { received.append(filters) }
    func didFinishWithFilters(filters: [FilterSet]) { finished.append(filters) }
}
