import XCTest
@testable import fearless

final class FiltersTests: XCTestCase {
    func testResetFilters_whenSwitchFiltersAreSelected_thenResetsAndPublishesFilters() {
        let interactor = FiltersInteractor(
            filters: [
                FilterSet(
                    title: "Availability",
                    items: [
                        TestSwitchFilterItem(id: "enabled", title: "Enabled", selected: true),
                        TestSwitchFilterItem(id: "disabled", title: "Disabled", selected: false)
                    ]
                )
            ],
            mode: .multiSelection
        )
        let presenter = FiltersInteractorOutputSpy()
        interactor.presenter = presenter

        interactor.resetFilters()

        let items = presenter.receivedFilters.first?.items.compactMap { $0 as? TestSwitchFilterItem }
        XCTAssertEqual(items?.map(\.selected), [false, false])
    }

    func testSwitchFilterState_whenAnyFilterIsSelected_thenCompletionReturnsValidState() {
        let interactor = FiltersInteractor(
            filters: [
                FilterSet(
                    title: nil,
                    items: [
                        TestSwitchFilterItem(id: "enabled", title: "Enabled", selected: false)
                    ]
                )
            ],
            mode: .multiSelection
        )

        var isValid = false
        interactor.switchFilterState(id: "enabled", selected: true) { selectedFiltersExist in
            isValid = selectedFiltersExist
        }

        XCTAssertTrue(isValid)
    }

    func testApplySort_whenSortIdIsProvided_thenPublishesOnlySelectedSort() {
        let interactor = FiltersInteractor(
            filters: [
                FilterSet(
                    title: "Sort",
                    items: AssetNetworksSort.defaultFilters(selected: .fiat)
                )
            ],
            mode: .singleSelection
        )
        let presenter = FiltersInteractorOutputSpy()
        interactor.presenter = presenter

        interactor.applySort(sortId: AssetNetworksSortType.name.id)

        let sortItems = presenter.finishedFilters.first?.items.compactMap { $0 as? AssetNetworksSort }
        XCTAssertEqual(sortItems?.first(where: \.selected)?.type, .name)
        XCTAssertEqual(sortItems?.filter(\.selected).count, 1)
    }

    func testViewModelFactory_whenFiltersContainSwitchAndSortItems_thenBuildsMatchingCellViewModels() {
        let delegate = SwitchFilterDelegateSpy()
        let viewModel = FiltersViewModelFactory().buildViewModel(
            from: [
                FilterSet(
                    title: "Sort",
                    items: [AssetNetworksSort(type: .popularity, selected: true)]
                ),
                FilterSet(
                    title: "Network",
                    items: [TestSwitchFilterItem(id: "polkadot", title: "Polkadot", selected: false)]
                )
            ],
            delegate: delegate,
            mode: .multiSelection
        )

        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertTrue(viewModel.sections[0].items.first is SortFilterCellViewModel)

        let switchViewModel = viewModel.sections[1].items.first as? SwitchFilterTableCellViewModel
        XCTAssertEqual(switchViewModel?.id, "polkadot")

        switchViewModel?.switcherValueChanged(isOn: true)

        XCTAssertEqual(delegate.changedFilterId, "polkadot")
        XCTAssertEqual(delegate.changedSelected, true)
    }
}

private struct TestSwitchFilterItem: SwitchFilterItem {
    let id: String
    let title: String
    var selected: Bool

    mutating func reset() {
        selected = false
    }
}

private final class FiltersInteractorOutputSpy: FiltersInteractorOutputProtocol {
    private(set) var receivedFilters: [FilterSet] = []
    private(set) var finishedFilters: [FilterSet] = []

    func didReceive(filters: [FilterSet]) {
        receivedFilters = filters
    }

    func didFinishWithFilters(filters: [FilterSet]) {
        finishedFilters = filters
    }
}

private final class SwitchFilterDelegateSpy: SwitchFilterTableCellViewModelDelegate {
    private(set) var changedFilterId: String?
    private(set) var changedSelected: Bool?

    func filterStateChanged(filterId: String, selected: Bool) {
        changedFilterId = filterId
        changedSelected = selected
    }
}
