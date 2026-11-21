import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovASearchDelegateSpy: ValidatorSearchRelaychainDelegate {
    private(set) var updates: [[SelectedValidatorInfo]] = []
    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo]) {
        updates.append(selectedValidatorList)
    }
}

final class CovASearchListenerSpy: ValidatorSearchModelStateListener {
    private(set) var events: [String] = []
    private(set) var notFound: [AccountId] = []

    func modelStateDidChanged(viewModelState _: ValidatorSearchViewModelState) {
        events.append("changed")
    }

    func viewModelChanged(_: ValidatorSearchViewModel) {
        events.append("viewModel")
    }

    func didStartLoading() {
        events.append("start")
    }

    func didStopLoading() {
        events.append("stop")
    }

    func didReceiveError(error _: Error) {
        events.append("error")
    }

    func didNotFoundLocalValidator(accountId: AccountId) {
        notFound.append(accountId)
    }
}

final class CovASearchViewStub: UIViewController, ValidatorSearchViewProtocol {
    private(set) var events: [String] = []
    private(set) var viewModels: [ValidatorSearchViewModel] = []

    func didReload(_ viewModel: ValidatorSearchViewModel) {
        events.append("reload")
        viewModels.append(viewModel)
    }

    func didStartSearch() {
        events.append("start")
    }

    func didStopSearch() {
        events.append("stop")
    }

    func didReset() {
        events.append("reset")
    }

    func applyLocalization() {}
}

final class CovASearchWireframeStub: ValidatorSearchWireframeProtocol {
    private(set) var infoFlows: [ValidatorInfoFlow] = []
    private(set) var closes = 0

    func present(flow: ValidatorInfoFlow, chainAsset _: ChainAsset, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?) {
        infoFlows.append(flow)
    }

    func close(_: ControllerBackedProtocol?) {
        closes += 1
    }
}

final class CovASearchPresenterSpy: ValidatorSearchPresenterProtocol {
    private(set) var calls: [String] = []
    func setup() {
        calls.append("setup")
    }

    func changeValidatorSelection(at index: Int) {
        calls.append("select:\(index)")
    }

    func search(for textEntry: String) {
        calls.append("search:\(textEntry)")
    }

    func didSelectValidator(at index: Int) {
        calls.append("info:\(index)")
    }

    func applyChanges() {
        calls.append("apply")
    }

    func applyLocalization() {}
}

final class CovAValidatorSearchTests: XCTestCase {
    private let locale = CovAFixtures.locale

    private func validators() -> [SelectedValidatorInfo] {
        [
            CovAFixtures.validator(1, identity: CovAFixtures.identity(name: "Alpha Node"), stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.1)),
            CovAFixtures.validator(2, identity: CovAFixtures.identity(name: "Alpine"), stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.3)),
            CovAFixtures.validator(3, identity: CovAFixtures.identity(name: "Blocked"), blocked: true)
        ]
    }

    private func makeState(delegate: ValidatorSearchRelaychainDelegate? = nil) -> ValidatorSearchRelaychainViewModelState {
        ValidatorSearchRelaychainViewModelState(
            fullValidatorList: validators(),
            selectedValidatorList: [validators()[0]],
            delegate: delegate
        )
    }

    private func factory() -> ValidatorSearchRelaychainViewModelFactory {
        ValidatorSearchRelaychainViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            balanceViewModelFactory: CovAFixtures.balanceFactory()
        )
    }

    func testStateSearchesByNameAndAddress() throws {
        let delegate = CovASearchDelegateSpy()
        let state = makeState(delegate: delegate)
        let listener = CovASearchListenerSpy()
        state.setStateListener(listener)

        state.searchString = "alp"
        state.performSearch()
        XCTAssertEqual(state.filteredValidatorList.map(\.address), [CovAFixtures.address(2), CovAFixtures.address(1)])

        state.performFullAddressSearch(by: CovAFixtures.address(3), accountId: CovAFixtures.accountId(3))
        XCTAssertEqual(state.filteredValidatorList.map(\.address), [CovAFixtures.address(3)])
        state.performFullAddressSearch(by: CovAFixtures.address(50), accountId: CovAFixtures.accountId(50))
        XCTAssertEqual(listener.notFound, [CovAFixtures.accountId(50)])

        state.didReceiveValidatorInfo(CovAFixtures.validator(50))
        XCTAssertEqual(state.fullValidatorList.count, 4)
        XCTAssertEqual(state.filteredValidatorList.count, 1)
        state.didReceiveValidatorInfo(nil)
        XCTAssertTrue(state.filteredValidatorList.isEmpty)
        state.didReceiveError(CovATestError.failed)
        XCTAssertEqual(listener.events, ["changed", "changed", "stop", "changed", "stop", "changed", "error"])

        guard case let .relaychain(info, _) = try XCTUnwrap({ () -> ValidatorInfoFlow? in
            state.searchString = "Alpine"
            state.performSearch()
            return state.validatorInfoFlow(index: 0)
        }()) else { return XCTFail("info flow") }
        XCTAssertEqual(info?.address, CovAFixtures.address(2))

        state.applyChanges()
        XCTAssertEqual(delegate.updates.first?.count, 1)
        state.reset()
        XCTAssertTrue(state.filteredValidatorList.isEmpty)
    }

    func testStateTogglesSelectionAgainstViewModel() throws {
        let state = makeState()
        let listener = CovASearchListenerSpy()
        state.setStateListener(listener)
        state.searchString = "l"
        state.performSearch()
        state.changeValidatorSelection(at: 0)
        XCTAssertFalse(listener.events.contains("viewModel"), "nothing to toggle without a view model")

        let viewModel = try XCTUnwrap(factory().buildViewModel(viewModelState: state, locale: locale))
        state.updateViewModel(viewModel)
        let blockedIndex = try XCTUnwrap(state.filteredValidatorList.firstIndex { $0.blocked })
        state.changeValidatorSelection(at: blockedIndex)
        XCTAssertEqual(listener.events.last, "error")

        let alphaIndex = try XCTUnwrap(state.filteredValidatorList.firstIndex { $0.address == CovAFixtures.address(1) })
        state.changeValidatorSelection(at: alphaIndex)
        XCTAssertTrue(state.selectedValidatorList.isEmpty)
        state.changeValidatorSelection(at: alphaIndex)
        XCTAssertEqual(state.selectedValidatorList.count, 1)
        XCTAssertEqual(listener.events.filter { $0 == "viewModel" }.count, 2)
    }

    func testFactoryBuildsHeaderCellsAndEmptyModel() throws {
        let state = makeState()
        let empty = try XCTUnwrap(factory().buildViewModel(viewModelState: state, locale: locale))
        XCTAssertNil(empty.headerViewModel)
        XCTAssertTrue(empty.cellViewModels.isEmpty)

        state.searchString = "l"
        state.performSearch()
        let viewModel = try XCTUnwrap(factory().buildViewModel(viewModelState: state, locale: locale))
        XCTAssertEqual(viewModel.cellViewModels.count, 3)
        XCTAssertNotNil(viewModel.headerViewModel)
        let alpha = try XCTUnwrap(viewModel.cellViewModels.first { $0.address == CovAFixtures.address(1) })
        XCTAssertTrue(alpha.isSelected)
        XCTAssertEqual(alpha.name, "Alpha Node")
        XCTAssertNotNil(alpha.detailsAttributedString)
    }

    func testPresenterSearchFlow() {
        let state = makeState(delegate: CovASearchDelegateSpy())
        let wireframe = CovASearchWireframeStub()
        let operationFactory = CovAValidatorOperationFactoryStub()
        operationFactory.selectedResult = [CovAFixtures.validator(60, identity: CovAFixtures.identity(name: "Remote"))]
        let strategy = ValidatorSearchRelaychainStrategy(
            validatorOperationFactory: operationFactory,
            operationManager: OperationManager(),
            output: state
        )
        let interactor = ValidatorSearchInteractor(strategy: strategy)
        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: factory(),
            viewModelState: state,
            localizationManager: CovAFixtures.localizationManager,
            logger: Logger.shared,
            chainAsset: CovAFixtures.chainAsset(),
            wallet: CovAFixtures.wallet()
        )
        let view = CovASearchViewStub()
        view.loadViewIfNeeded()
        presenter.view = view
        interactor.presenter = presenter

        presenter.setup()
        XCTAssertEqual(view.events, ["reset"])

        presenter.search(for: "alp")
        XCTAssertEqual(view.viewModels.last?.cellViewModels.count, 2)
        presenter.changeValidatorSelection(at: 0)
        presenter.didSelectValidator(at: 0)
        XCTAssertEqual(wireframe.infoFlows.count, 1)

        presenter.search(for: CovAFixtures.address(60))
        CovAViewInspector.spin(until: { view.viewModels.last?.cellViewModels.first?.name == "Remote" })
        XCTAssertEqual(operationFactory.wannabeRequests, [[CovAFixtures.accountId(60)]])
        XCTAssertEqual(view.viewModels.last?.cellViewModels.first?.name, "Remote")
        XCTAssertTrue(view.events.contains("start"))
        XCTAssertTrue(view.events.contains("stop"))

        presenter.didReceiveError(error: CovATestError.failed)
        XCTAssertEqual(view.events.last, "reset")
        presenter.search(for: "")
        XCTAssertEqual(view.events.last, "reset")
        presenter.applyLocalization()
        presenter.applyChanges()
        XCTAssertEqual(wireframe.closes, 1)
    }

    func testStrategyReportsEmptyAndFailedSearches() {
        final class CovASearchOutputSpy: ValidatorSearchRelaychainStrategyOutput {
            var infos: [SelectedValidatorInfo?] = []
            var errors = 0
            func didReceiveValidatorInfo(_ validatorInfo: SelectedValidatorInfo?) {
                infos.append(validatorInfo)
            }

            func didReceiveError(_: Error) {
                errors += 1
            }
        }
        let output = CovASearchOutputSpy()
        let emptyFactory = CovAValidatorOperationFactoryStub()
        let failingFactory = CovAValidatorOperationFactoryStub()
        failingFactory.error = CovATestError.failed
        let emptyStrategy = ValidatorSearchRelaychainStrategy(
            validatorOperationFactory: emptyFactory, operationManager: OperationManager(), output: output
        )
        let failingStrategy = ValidatorSearchRelaychainStrategy(
            validatorOperationFactory: failingFactory, operationManager: OperationManager(), output: output
        )
        emptyStrategy.performValidatorSearch(accountId: CovAFixtures.accountId(1))
        failingStrategy.performValidatorSearch(accountId: CovAFixtures.accountId(2))
        CovAViewInspector.spin(until: { output.infos.count + output.errors >= 2 })
        XCTAssertEqual(output.infos.count, 1)
        XCTAssertNil(output.infos.first.flatMap { $0 })
        XCTAssertEqual(output.errors, 1)
    }

    func testViewControllerSearchInputAndTable() throws {
        let presenter = CovASearchPresenterSpy()
        let controller = ValidatorSearchViewController(presenter: presenter, localizationManager: CovAFixtures.localizationManager)
        let window = CovAViewInspector.host(UINavigationController(rootViewController: controller))
        XCTAssertEqual(presenter.calls.first, "setup")
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        XCTAssertNotNil(controller.viewForEmptyState)

        let state = makeState()
        state.searchString = "l"
        state.performSearch()
        let viewModel = try XCTUnwrap(factory().buildViewModel(viewModelState: state, locale: locale))
        controller.didReload(viewModel)
        let table = controller.rootView.tableView
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)
        XCTAssertNotNil(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? CustomValidatorCell)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(presenter.calls.last, "select:1")

        let field = controller.rootView.searchField
        field.text = "al"
        XCTAssertTrue(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 2, length: 0), replacementString: "p"))
        XCTAssertEqual(presenter.calls.last, "search:alp")
        XCTAssertFalse(controller.textFieldShouldReturn(field))
        XCTAssertTrue(controller.textFieldShouldClear(field))
        XCTAssertEqual(presenter.calls.last, "search:")

        controller.didStartSearch()
        XCTAssertNotNil(field.rightView)
        controller.didStopSearch()
        XCTAssertNil(field.rightView)
        controller.didReset()
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertNotNil(controller.viewForEmptyState)

        if let doneButton = controller.navigationItem.rightBarButtonItem {
            _ = doneButton.target?.perform(doneButton.action)
            XCTAssertEqual(presenter.calls.last, "apply")
        }
        controller.applyLocalization()
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        window.isHidden = true
    }
}
