import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovACustomListListenerSpy: CustomValidatorListModelStateListener {
    private(set) var changes = 0
    private(set) var blockedErrors = 0
    private(set) var selectedListRequests = 0
    private(set) var confirmationRequests = 0

    func modelStateDidChanged(viewModelState _: CustomValidatorListViewModelState) {
        changes += 1
    }

    func didReceiveError(error _: CustomValidatorListFlowError) {
        blockedErrors += 1
    }

    func showSelectedList() {
        selectedListRequests += 1
    }

    func showConfirmation() {
        confirmationRequests += 1
    }
}

final class CovACustomListViewStub: UIViewController, CustomValidatorListViewProtocol {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
        completion?()
    }

    private(set) var viewModels: [CustomValidatorListViewModel] = []
    private(set) var filterStates: [Bool] = []

    func reload(_ viewModel: CustomValidatorListViewModel, at _: [Int]?) {
        viewModels.append(viewModel)
    }

    func setFilterAppliedState(to state: Bool) {
        filterStates.append(state)
    }

    func applyLocalization() {}
}

final class CovACustomListWireframeStub: CustomValidatorListWireframeProtocol {
    private(set) var events: [String] = []
    private(set) var deselectActions: [() -> Void] = []

    func present(chainAsset _: ChainAsset, wallet _: MetaAccountModel, flow _: ValidatorInfoFlow, from _: ControllerBackedProtocol?) {
        events.append("info")
    }

    func presentFilters(
        from _: ControllerBackedProtocol?,
        flow _: ValidatorListFilterFlow,
        delegate _: ValidatorListFilterDelegate?,
        asset _: AssetModel
    ) {
        events.append("filters")
    }

    func presentSearch(from _: ControllerBackedProtocol?, flow _: ValidatorSearchFlow, chainAsset _: ChainAsset, wallet _: MetaAccountModel) {
        events.append("search")
    }

    func proceed(
        from _: ControllerBackedProtocol?,
        flow _: SelectedValidatorListFlow,
        delegate _: SelectedValidatorListDelegate,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        events.append("proceed")
    }

    func confirm(from _: ControllerBackedProtocol?, flow _: SelectValidatorsConfirmFlow, chainAsset _: ChainAsset, wallet _: MetaAccountModel) {
        events.append("confirm")
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        events.append("message")
    }

    func presentDeselectValidatorsWarning(from _: ControllerBackedProtocol, action: @escaping () -> Void, locale _: Locale?) {
        events.append("deselectWarning")
        deselectActions.append(action)
    }
}

final class CovACustomListPresenterSpy: CustomValidatorListPresenterProtocol {
    private(set) var calls: [String] = []
    private(set) var searches: [String?] = []

    func setup() {
        calls.append("setup")
    }

    func fillWithRecommended() {
        calls.append("fill")
    }

    func clearFilter() {
        calls.append("clear")
    }

    func deselectAll() {
        calls.append("deselect")
    }

    func changeValidatorSelection(address: String) {
        calls.append("select:\(address)")
    }

    func didSelectValidator(address: String) {
        calls.append("info:\(address)")
    }

    func presentFilter() {
        calls.append("filter")
    }

    func presentSearch() {
        calls.append("search")
    }

    func changeIdentityFilterValue() {
        calls.append("identity")
    }

    func changeMinBondFilterValue() {
        calls.append("minBond")
    }

    func proceed() {
        calls.append("proceed")
    }

    func searchTextDidChange(_ text: String?) {
        searches.append(text)
    }

    func didRemove(_ validator: SelectedValidatorInfo) {
        calls.append("remove:\(validator.address)")
    }

    func didRemove(validatorAddress: AccountAddress) {
        calls.append("removeAddress:\(validatorAddress)")
    }
}

enum CovACustomListFixtures {
    static func validators() -> [SelectedValidatorInfo] {
        [
            CovAFixtures.validator(1, identity: CovAFixtures.identity(name: "Alpha"), stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.3)),
            CovAFixtures.validator(2, identity: CovAFixtures.identity(name: "Beta"), stakeInfo: CovAFixtures.stakeInfo(
                nominatorStakes: [1], total: 500, stakeReturn: 0.2, maxNominatorsRewarded: 5
            )),
            CovAFixtures.validator(3, stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.1), hasSlashes: true),
            CovAFixtures.validator(4, identity: CovAFixtures.identity(name: "Blocked"), stakeInfo: nil, blocked: true, elected: false),
            CovAFixtures.validator(5, identity: CovAFixtures.identity(name: "Waiting"), stakeInfo: nil, commission: 0.03, elected: false)
        ]
    }

    static func flows(
        validators: [SelectedValidatorInfo],
        selected: SharedList<SelectedValidatorInfo>
    ) -> [CustomValidatorListFlow] {
        let recommended = Array(validators.prefix(2))
        return [
            .relaychainInitiated(
                validatorList: validators, recommendedValidatorList: recommended, selectedValidatorList: selected,
                maxTargets: 3, bonding: CovAConfirmFixtures.initiated(payout: false)
            ),
            .relaychainExisting(
                validatorList: validators, recommendedValidatorList: recommended, selectedValidatorList: selected,
                maxTargets: 3, bonding: CovAConfirmFixtures.existing(payout: true)
            ),
            .poolExisting(
                validatorList: validators, recommendedValidatorList: recommended, selectedValidatorList: selected,
                poolId: 2, maxTargets: 3, bonding: CovAConfirmFixtures.existing(payout: false)
            ),
            .poolInitiated(
                validatorList: validators, recommendedValidatorList: recommended, selectedValidatorList: selected,
                poolId: 2, maxTargets: 3, bonding: CovAConfirmFixtures.initiated(payout: true)
            )
        ]
    }

    static func state(flowIndex: Int = 0, selected: [SelectedValidatorInfo] = []) -> CustomValidatorListRelaychainViewModelState {
        let validators = validators()
        let list = SharedList(items: selected)
        let flow = flows(validators: validators, selected: list)[flowIndex]
        return CustomValidatorListRelaychainViewModelState(
            baseFlow: flow,
            fullValidatorList: validators,
            recommendedValidatorList: Array(validators.prefix(2)),
            selectedValidatorList: list,
            maxTargets: 3
        )
    }

    static func factory() -> CustomValidatorListRelaychainViewModelFactory {
        CustomValidatorListRelaychainViewModelFactory(
            balanceViewModelFactory: CovAFixtures.balanceFactory(),
            iconGenerator: UniversalIconGenerator()
        )
    }
}

final class CovACustomValidatorListTests: XCTestCase {
    private let locale = CovAFixtures.locale

    func testStateFiltersAndRecommendedFill() throws {
        let state = CovACustomListFixtures.state()
        let listener = CovACustomListListenerSpy()
        state.setStateListener(listener)

        // the recommended filter drops validators without identity, slashed and oversubscribed ones
        XCTAssertTrue(state.filterApplied)
        XCTAssertFalse(state.filteredValidatorList.contains { $0.address == CovAFixtures.address(3) })

        state.clearFilter()
        XCTAssertFalse(state.filterApplied)
        XCTAssertEqual(state.filteredValidatorList.count, 5)
        XCTAssertEqual(state.filteredValidatorList.first?.address, CovAFixtures.address(1))

        var filter = CustomValidatorRelaychainListFilter.defaultFilter()
        filter.sortedBy = .totalStake
        state.updateFilter(with: .relaychain(filter: filter))
        XCTAssertEqual(state.filteredValidatorList.first?.address, CovAFixtures.address(2))
        filter.sortedBy = .ownStake
        state.updateFilter(with: .relaychain(filter: filter))
        XCTAssertEqual(state.filteredValidatorList.first?.address, CovAFixtures.address(2))
        guard case let .relaychain(current) = try XCTUnwrap(state.validatorListFilterFlow()) else { return XCTFail("filter flow") }
        XCTAssertEqual(current.sortedBy, .ownStake)

        state.fillWithRecommended()
        XCTAssertEqual(state.selectedValidatorList.count, 2)
        XCTAssertEqual(listener.changes, 1)
        state.fillWithRecommended()
        XCTAssertEqual(listener.changes, 1, "nothing left to fill")

        state.performDeselect()
        XCTAssertEqual(state.selectedValidatorList.count, 0)
        XCTAssertEqual(listener.changes, 2)

        state.proceed()
        XCTAssertEqual(listener.selectedListRequests, 1)
        XCTAssertNil(state.selectValidatorsConfirmFlow())
    }

    func testSelectionChangesAndRemovals() throws {
        let state = CovACustomListFixtures.state()
        let listener = CovACustomListListenerSpy()
        state.setStateListener(listener)
        state.clearFilter()

        state.changeValidatorSelection(address: CovAFixtures.address(1))
        XCTAssertEqual(listener.changes, 0, "no view model yet")

        let viewModel = try XCTUnwrap(CovACustomListFixtures.factory().buildViewModel(
            viewModelState: state, priceData: nil, locale: locale, searchText: nil
        ))
        state.updateViewModel(viewModel)
        XCTAssertEqual(state.viewModel?.selectedValidatorsCount, 0)

        state.changeValidatorSelection(address: CovAFixtures.address(1))
        state.changeValidatorSelection(address: CovAFixtures.address(2))
        XCTAssertEqual(state.selectedValidatorList.count, 2)
        XCTAssertEqual(state.viewModel?.selectedValidatorsCount, 2)
        state.changeValidatorSelection(address: CovAFixtures.address(2))
        XCTAssertEqual(state.selectedValidatorList.count, 1)
        state.changeValidatorSelection(address: CovAFixtures.address(4))
        XCTAssertEqual(listener.blockedErrors, 1)
        state.changeValidatorSelection(address: "missing")
        XCTAssertEqual(listener.changes, 3)

        state.remove(validatorAddress: CovAFixtures.address(1))
        XCTAssertEqual(state.selectedValidatorList.count, 0)
        state.remove(validatorAddress: "missing")

        // a selected validator that is filtered out is removed from the list directly
        state.selectedValidatorList.append(CovAFixtures.validator(77))
        state.remove(validator: CovAFixtures.validator(77))
        XCTAssertEqual(state.selectedValidatorList.count, 0)

        state.validatorSearchDidUpdate(selectedValidatorList: [CovAFixtures.validator(5)])
        XCTAssertEqual(state.selectedValidatorList.items.map(\.address), [CovAFixtures.address(5)])

        guard case let .relaychain(info, _) = try XCTUnwrap(state.validatorInfoFlow(address: CovAFixtures.address(5))) else {
            return XCTFail("info flow")
        }
        XCTAssertEqual(info?.address, CovAFixtures.address(5))
        XCTAssertNil(state.validatorInfoFlow(address: "missing"))
        guard case let .relaychain(all, selected, _) = try XCTUnwrap(state.validatorSearchFlow()) else { return XCTFail("search flow") }
        XCTAssertEqual(all.count, 5)
        XCTAssertEqual(selected.count, 1)
    }

    func testSelectedListFlowForEveryBaseFlow() throws {
        for index in 0 ..< 4 {
            let empty = CovACustomListFixtures.state(flowIndex: index)
            XCTAssertNil(empty.selectedValidatorListFlow())
            let state = CovACustomListFixtures.state(flowIndex: index, selected: [CovAFixtures.validator(1)])
            let flow = try XCTUnwrap(state.selectedValidatorListFlow())
            switch (index, flow) {
            case let (0, .relaychainInitiated(list, maxTargets, _)):
                XCTAssertEqual(list.count, 1)
                XCTAssertEqual(maxTargets, 3)
            case (1, .relaychainExisting):
                break
            case let (2, .poolExisting(_, poolId, _, _)):
                XCTAssertEqual(poolId, 2)
            case let (3, .poolInitiated(_, poolId, _, _)):
                XCTAssertEqual(poolId, 2)
            default:
                XCTFail("unexpected flow for \(index)")
            }
        }
    }

    func testFactoryBuildsSectionsHeaderAndButtonTitle() throws {
        let state = CovACustomListFixtures.state(selected: [CovAFixtures.validator(5)])
        state.clearFilter()
        let factory = CovACustomListFixtures.factory()
        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil, locale: locale, searchText: nil))
        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertEqual(viewModel.sections[0].cells.count, 3)
        XCTAssertEqual(viewModel.sections[1].cells.count, 2)
        XCTAssertTrue(viewModel.sections[1].cells[0].isSelected, "selected validators come first")
        XCTAssertEqual(viewModel.sections[1].cells[0].name, "Waiting")
        XCTAssertNil(viewModel.sections[1].cells[0].auxDetails)
        XCTAssertTrue(try XCTUnwrap(viewModel.sections[1].cells[0].detailsAttributedString?.string).contains("3"))
        XCTAssertTrue(viewModel.sections[1].cells[1].shouldShowWarning, "blocked validators warn")
        XCTAssertTrue(viewModel.sections[0].cells[2].shouldShowError)
        XCTAssertTrue(try XCTUnwrap(viewModel.sections[0].cells[0].detailsAttributedString?.string).hasPrefix("APY"))
        XCTAssertNotNil(viewModel.sections[0].cells[0].auxDetails)
        XCTAssertEqual(viewModel.selectedValidatorsCount, 1)
        XCTAssertEqual(viewModel.selectedValidatorsLimit, 3)
        XCTAssertTrue(try XCTUnwrap(viewModel.proceedButtonTitle).contains("1"))
        XCTAssertTrue(viewModel.headerViewModel.title.contains("5"))
        XCTAssertFalse(viewModel.title.isEmpty)

        let searched = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil, locale: locale, searchText: "alp"))
        XCTAssertEqual(searched.sections.flatMap(\.cells).map(\.name), ["Alpha"])
        let byAddress = try XCTUnwrap(factory.buildViewModel(
            viewModelState: state, priceData: nil, locale: locale, searchText: CovAFixtures.address(3)
        ))
        XCTAssertEqual(byAddress.sections.flatMap(\.cells).count, 1)

        var filter = CustomValidatorRelaychainListFilter.defaultFilter()
        for sort in CustomValidatorRelaychainListFilter.CustomValidatorListSort.allCases {
            filter.sortedBy = sort
            state.updateFilter(with: .relaychain(filter: filter))
            let sorted = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil, locale: locale, searchText: nil))
            XCTAssertFalse(sorted.headerViewModel.subtitle.isEmpty)
        }
        let emptySelection = try XCTUnwrap(factory.buildViewModel(
            viewModelState: CovACustomListFixtures.state(), priceData: nil, locale: locale, searchText: nil
        ))
        XCTAssertTrue(try XCTUnwrap(emptySelection.proceedButtonTitle).contains("3"))
    }

    // MARK: - Presenter

    private func makePresenter(
        state: CustomValidatorListRelaychainViewModelState
    ) -> (CustomValidatorListPresenter, CovACustomListViewStub, CovACustomListWireframeStub) {
        let wireframe = CovACustomListWireframeStub()
        let presenter = CustomValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: CovACustomListFixtures.factory(),
            viewModelState: state,
            localizationManager: CovAFixtures.localizationManager,
            logger: Logger.shared,
            chainAsset: CovAFixtures.chainAsset(),
            wallet: CovAFixtures.wallet()
        )
        let view = CovACustomListViewStub()
        view.loadViewIfNeeded()
        presenter.view = view
        return (presenter, view, wireframe)
    }

    func testPresenterRoutesUserActions() throws {
        let state = CovACustomListFixtures.state()
        let (presenter, view, wireframe) = makePresenter(state: state)
        presenter.setup()
        XCTAssertEqual(view.viewModels.count, 1)
        XCTAssertEqual(view.filterStates, [true])

        presenter.clearFilter()
        XCTAssertEqual(view.filterStates.last, false)
        presenter.searchTextDidChange("beta")
        XCTAssertEqual(view.viewModels.last?.sections.flatMap(\.cells).count, 1)
        presenter.searchTextDidChange(nil)

        presenter.changeValidatorSelection(address: CovAFixtures.address(1))
        XCTAssertEqual(state.selectedValidatorList.count, 1)
        presenter.changeValidatorSelection(address: CovAFixtures.address(4))
        XCTAssertTrue(view.presentedControllers.last is SheetAletViewController, "blocked validators raise a warning")
        presenter.didSelectValidator(address: CovAFixtures.address(1))
        presenter.didSelectValidator(address: "missing")
        presenter.presentFilter()
        presenter.presentSearch()
        presenter.proceed()
        presenter.showConfirmation()
        presenter.fillWithRecommended()
        XCTAssertEqual(state.selectedValidatorList.count, 2)
        presenter.changeIdentityFilterValue()
        presenter.changeMinBondFilterValue()

        presenter.deselectAll()
        try XCTUnwrap(wireframe.deselectActions.first)()
        XCTAssertEqual(state.selectedValidatorList.count, 0)

        presenter.didUpdate(with: .relaychain(filter: .recommendedFilter()))
        XCTAssertEqual(view.filterStates.last, true)
        presenter.didRemove(CovAFixtures.validator(1))
        presenter.didRemove(validatorAddress: CovAFixtures.address(1))
        presenter.applyLocalization()

        XCTAssertEqual(wireframe.events, ["info", "filters", "search", "proceed", "deselectWarning"])
    }

    func testPresenterWithoutViewSkipsDeselectWarning() {
        let (presenter, _, wireframe) = makePresenter(state: CovACustomListFixtures.state())
        presenter.view = nil
        presenter.deselectAll()
        XCTAssertTrue(wireframe.events.isEmpty)
    }

    // MARK: - View controller

    func testViewControllerRendersListAndForwardsActions() throws {
        let presenter = CovACustomListPresenterSpy()
        let controller = CustomValidatorListViewController(presenter: presenter, localizationManager: CovAFixtures.localizationManager)
        let window = CovAViewInspector.host(controller)
        XCTAssertEqual(presenter.calls.first, "setup")

        let state = CovACustomListFixtures.state(selected: [CovAFixtures.validator(1)])
        state.clearFilter()
        let viewModel = try XCTUnwrap(CovACustomListFixtures.factory().buildViewModel(
            viewModelState: state, priceData: nil, locale: locale, searchText: nil
        ))
        controller.reload(viewModel, at: nil)
        controller.setFilterAppliedState(to: false)
        let table = controller.rootView.tableView
        table.layoutIfNeeded()

        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)
        XCTAssertNotNil(controller.tableView(table, viewForHeaderInSection: 1))
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? CustomValidatorCell)
        XCTAssertEqual(cell.titleLabel.text, "Alpha")
        let waitingTitles = try (0 ..< 2).map { row in
            try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: row, section: 1)) as? CustomValidatorCell).titleLabel.text
        }
        XCTAssertEqual(Set(waitingTitles.compactMap { $0 }), ["Blocked", "Waiting"])

        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(presenter.calls.last, "select:\(CovAFixtures.address(1))")

        if let visible = table.visibleCells.first as? CustomValidatorCell {
            visible.infoButton.sendActions(for: .touchUpInside)
            XCTAssertTrue(presenter.calls.last?.hasPrefix("info:") ?? false)
        }
        controller.reload(viewModel, at: [0])

        controller.rootView.proceedButton.sendActions(for: .touchUpInside)
        controller.filterButton.sendActions(for: .touchUpInside)
        controller.rootView.searchTextField.onTextDidChanged?("alpha")
        XCTAssertTrue(presenter.calls.contains("proceed"))
        XCTAssertTrue(presenter.calls.contains("filter"))
        XCTAssertEqual(presenter.searches.last, "alpha")
        XCTAssertNotNil(controller.viewForEmptyState)

        var empty = viewModel
        empty.sections = []
        empty.selectedValidatorsCount = 0
        controller.reload(empty, at: nil)
        XCTAssertEqual(controller.numberOfSections(in: table), 0)
        controller.applyLocalization()
        window.isHidden = true
    }
}
