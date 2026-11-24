import SoraFoundation
import UIKit
import XCTest
@testable import fearless

struct CovHNftPlainFilter: BaseFilterItem {
    var id: String
    var title: String

    mutating func reset() {}
}

final class CovHNftFiltersViewSpy: CovHNftHostController, NftFiltersViewProtocol {
    private(set) var states: [FiltersViewState] = []
    private(set) var locales: [Locale] = []

    func didReceive(state: FiltersViewState) { states.append(state) }
    func didReceive(locale: Locale) { locales.append(locale) }
}

final class CovHNftFiltersOutputSpy: NftFiltersModuleOutput {
    private(set) var results: [[FilterSet]] = []

    func didFinishWithFilters(filters: [FilterSet]) {
        results.append(filters)
    }
}

final class CovHNftFiltersPresenterSpy: NftFiltersPresenterProtocol {
    private(set) var calls: [String] = []

    func setup() { calls.append("setup") }
    func didTapCloseButton() { calls.append("close") }
    func willDisappear() { calls.append("disappear") }
}

final class CovHNftFiltersTests: XCTestCase {
    private func defaultSets() -> [FilterSet] {
        [
            FilterSet(title: "Collections", items: NftCollectionFilter.defaultFilters()),
            FilterSet(title: nil, items: [CovHNftPlainFilter(id: "plain", title: "Plain")])
        ]
    }

    func testPresenterInteractorAndRouterRoundTrip() throws {
        let view = CovHNftFiltersViewSpy()
        let output = CovHNftFiltersOutputSpy()
        let interactor = NftFiltersInteractor(filters: defaultSets())
        let presenter = NftFiltersPresenter(
            interactor: interactor,
            router: NftFiltersRouter(),
            viewModelFactory: NftFiltersViewModelFactory(),
            moduleOutput: output,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        interactor.presenter = presenter

        presenter.setup()
        guard case let .loaded(viewModel) = try XCTUnwrap(view.states.first) else {
            return XCTFail("filters should be loaded")
        }
        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.sections[0].items.count, 2)
        XCTAssertTrue(viewModel.sections[1].items.isEmpty, "non-switch filters are skipped")
        XCTAssertEqual(view.locales.count, 1)

        presenter.filterStateChanged(filterId: "AIRDROPS", selected: true)
        presenter.filterStateChanged(filterId: "SPAM", selected: false)
        presenter.willDisappear()
        let result = try XCTUnwrap(output.results.first)
        let switches = result.flatMap(\.items).compactMap { $0 as? NftCollectionFilter }
        XCTAssertEqual(switches.map(\.selected), [false, true])

        presenter.applyLocalization()
        XCTAssertEqual(view.locales.count, 2)
        presenter.didTapCloseButton()
        XCTAssertEqual(view.dismissCount, 1)
    }

    func testInteractorReportsWhetherAnyFilterStaysSelected() {
        let interactor = NftFiltersInteractor(filters: defaultSets())
        var states: [Bool] = []
        interactor.switchFilterState(id: "SPAM", selected: false) { states.append($0) }
        interactor.switchFilterState(id: "missing", selected: true) { states.append($0) }
        interactor.switchFilterState(id: "plain", selected: true) { states.append($0) }
        interactor.switchFilterState(id: "AIRDROPS", selected: true) { states.append($0) }
        XCTAssertEqual(states, [false, false, false, true])
    }

    func testViewModelFactoryBuildsSwitchRows() throws {
        let viewModel = NftFiltersViewModelFactory().buildViewModel(from: defaultSets(), delegate: nil, mode: .singleSelection)
        let rows = viewModel.sections[0].items.compactMap { $0 as? SwitchFilterTableCellViewModel }
        XCTAssertEqual(rows.map(\.id), ["SPAM", "AIRDROPS"])
        XCTAssertEqual(rows.map(\.enabled), [true, false])
        XCTAssertEqual(viewModel.sections[0].title, "Collections")
        if case .multiSelection = viewModel.mode {} else {
            XCTFail("NFT filters always allow several selections")
        }
    }

    func testAssemblyBuildsModalFilterScreen() throws {
        let view = try XCTUnwrap(NftFiltersAssembly.configureModule(filters: defaultSets(), moduleOutput: nil))
        let controller = try XCTUnwrap(view as? NftFiltersViewController)
        XCTAssertEqual(controller.modalPresentationStyle, .custom)
        XCTAssertNotNil(controller.modalTransitioningFactory)
    }

    func testControllerRendersSectionsAndForwardsEvents() throws {
        let presenter = CovHNftFiltersPresenterSpy()
        let controller = NftFiltersViewController(presenter: presenter)
        controller.loadViewIfNeeded()
        let table = controller.rootView.tableView
        XCTAssertEqual(presenter.calls, ["setup"])
        XCTAssertEqual(controller.numberOfSections(in: table), 0)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertNil(controller.tableView(table, viewForHeaderInSection: 0))
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 0), 0)
        XCTAssertFalse(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) is SwitchFilterTableCell)

        controller.didReceive(state: .loading)
        XCTAssertTrue(table.isHidden)

        let viewModel = NftFiltersViewModelFactory().buildViewModel(
            from: defaultSets() + [FilterSet(title: "", items: [NftCollectionFilter(type: .spam)])],
            delegate: nil,
            mode: .multiSelection
        )
        controller.didReceive(state: .loaded(viewModel: viewModel))
        XCTAssertFalse(table.isHidden)
        XCTAssertEqual(controller.numberOfSections(in: table), 3)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 0), 40)
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 1), 0)
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 2), 0)
        let header = try XCTUnwrap(controller.tableView(table, viewForHeaderInSection: 0) as? FilterSectionHeaderView)
        XCTAssertEqual(header.titleLabel.text, "Collections")
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? SwitchFilterTableCell)
        XCTAssertFalse(cell.filterValueSwitch.isOn)
        XCTAssertEqual(cell.filterTitleLabel.text, NftCollectionFilter(type: .airdrop).title)

        let english = Locale(identifier: "en")
        controller.didReceive(locale: Locale(identifier: "de"))
        controller.didReceive(locale: english)
        XCTAssertEqual(controller.rootView.locale, english)

        controller.rootView.closeButton.sendActions(for: .touchUpInside)
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        controller.didReceive(state: .empty)
        XCTAssertTrue(table.isHidden)
        XCTAssertEqual(presenter.calls, ["setup", "close", "disappear"])
    }
}
