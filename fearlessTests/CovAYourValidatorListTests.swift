import BigInt
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

final class CovAYourValidatorListListenerSpy: YourValidatorListModelStateListener {
    private(set) var changes = 0
    private(set) var errors: [Error] = []
    private(set) var states: [YourValidatorListViewState] = []
    private(set) var missingControllers: [String] = []

    func modelStateDidChanged(viewModelState _: YourValidatorListViewModelState) {
        changes += 1
    }

    func didReceiveError(error: Error) {
        errors.append(error)
    }

    func didReceiveState(_ state: YourValidatorListViewState) {
        states.append(state)
    }

    func handleControllerAccountMissing(_ address: String) {
        missingControllers.append(address)
    }
}

final class CovAYourValidatorListViewStub: UIViewController, YourValidatorListViewProtocol {
    private(set) var states: [YourValidatorListViewState] = []
    private(set) var loading: [Bool] = []

    func reload(state: YourValidatorListViewState) {
        states.append(state)
    }

    func didStartLoading() {
        loading.append(true)
    }

    func didStopLoading() {
        loading.append(false)
    }

    func applyLocalization() {}
}

final class CovAYourValidatorListWireframeStub: YourValidatorListWireframeProtocol {
    private(set) var infoFlows: [ValidatorInfoFlow] = []
    private(set) var startFlows: [SelectValidatorsStartFlow] = []
    private(set) var missingControllers: [String] = []

    func present(flow: ValidatorInfoFlow, chainAsset _: ChainAsset, wallet _: MetaAccountModel, from _: YourValidatorListViewProtocol?) {
        infoFlows.append(flow)
    }

    func proceedToSelectValidatorsStart(
        from _: YourValidatorListViewProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow: SelectValidatorsStartFlow
    ) {
        startFlows.append(flow)
    }

    func presentMissingController(from _: ControllerBackedProtocol, address: AccountAddress, locale _: Locale?) {
        missingControllers.append(address)
    }
}

final class CovAYourValidatorListPresenterSpy: YourValidatorListPresenterProtocol {
    private(set) var calls: [String] = []
    private(set) var selected: [YourValidatorViewModel] = []

    func retry() {
        calls.append("retry")
    }

    func didSelectValidator(viewModel: YourValidatorViewModel) {
        selected.append(viewModel)
    }

    func changeValidators() {
        calls.append("change")
    }

    func didLoad(view _: YourValidatorListViewProtocol) {
        calls.append("load")
    }

    func willAppear(view _: YourValidatorListViewProtocol) {
        calls.append("appear")
    }
}

final class CovAYourValidatorListStrategySpy: YourValidatorListStrategy {
    private(set) var calls: [String] = []
    func setup() {
        calls.append("setup")
    }

    func refresh() {
        calls.append("refresh")
    }
}

enum CovAYourValidatorFixtures {
    static let chainAsset = CovAFixtures.chainAsset()
    static let wallet = CovAFixtures.wallet()

    static func model() -> YourValidatorsModel {
        let active = CovAFixtures.validator(
            1,
            identity: CovAFixtures.identity(name: "Active"),
            stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.2),
            myNomination: .active(allocation: ValidatorTokenAllocation(amount: 3, isRewarded: false)),
            hasSlashes: true
        )
        let elected = CovAFixtures.validator(2, stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.1), myNomination: .elected)
        let unelected = CovAFixtures.validator(3, stakeInfo: nil, myNomination: .unelected)
        let pending = CovAFixtures.validator(4, stakeInfo: CovAFixtures.stakeInfo(stakeReturn: 0.05))
        return YourValidatorsModel(currentValidators: [active, elected, unelected], pendingValidators: [pending])
    }

    static func ledger() throws -> StakingLedger {
        try XCTUnwrap(WestendStub.ledgerInfo.item)
    }

    static func controller() -> ChainAccountResponse {
        CovAConfirmFixtures.controller()
    }

    static func stakingPool(nominator: AccountId?) -> StakingPool {
        let roles = StakingPoolRoles(depositor: CovAFixtures.accountId(1), root: nil, nominator: nominator, bouncer: nil)
        let info = StakingPoolInfo(points: BigUInt(1_000_000_000_000), state: .open, memberCounter: 2, roles: roles)
        return StakingPool(id: "5", info: info, name: "Pool Five")
    }

    static func poolMember() throws -> StakingPoolMember {
        let json = #"{"poolId":"5","points":"2000000000000","lastRecordedRewardCounter":"0","unbondingEras":[]}"#
        return try JSONDecoder().decode(StakingPoolMember.self, from: Data(json.utf8))
    }
}

final class CovAYourValidatorListTests: XCTestCase {
    private let locale = CovAFixtures.locale

    // MARK: - Relaychain state

    func testRelaychainStateBuildsChangeFlowFromStakingData() throws {
        let state = YourValidatorListRelaychainViewModelState(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet,
            logger: Logger.shared
        )
        let listener = CovAYourValidatorListListenerSpy()
        state.setStateListener(listener)
        state.changeLocale(locale)
        XCTAssertNil(state.selectValidatorsStartFlow())

        let stash = StashItem(stash: CovAFixtures.address(7), controller: CovAFixtures.address(8))
        state.didReceiveStashItem(result: .success(stash))
        try state.didReceiveLedger(result: .success(CovAYourValidatorFixtures.ledger()))
        state.didReceiveRewardDestination(result: .success(.staked))
        XCTAssertNil(state.selectValidatorsStartFlow())
        XCTAssertEqual(listener.missingControllers, [CovAFixtures.address(8)])

        state.didReceiveController(result: .success(CovAYourValidatorFixtures.controller()))
        state.didReceiveValidators(result: .success(CovAYourValidatorFixtures.model()))
        XCTAssertEqual(listener.changes, 1)

        guard case let .relaychainExisting(bonding) = try XCTUnwrap(state.selectValidatorsStartFlow()) else {
            return XCTFail("existing relaychain bonding expected")
        }
        XCTAssertEqual(bonding.amount, 1)
        XCTAssertEqual(bonding.stashAddress, CovAFixtures.address(7))
        XCTAssertEqual(bonding.selectedTargets?.count, 1, "pending validators win over current ones")
        XCTAssertEqual(bonding.rewardDestination, .restake)

        guard case let .relaychain(info, address) = try XCTUnwrap(state.validatorInfoFlow(address: CovAFixtures.address(2))) else {
            return XCTFail("relaychain info flow expected")
        }
        XCTAssertEqual(info?.address, CovAFixtures.address(2))
        XCTAssertNil(address)
        XCTAssertNil(state.validatorInfoFlow(address: CovAFixtures.address(99)))

        state.resetState()
        XCTAssertNil(state.validatorsModel)
    }

    func testRelaychainStateErrorsClearValidatorsWithoutNotifying() {
        let state = YourValidatorListRelaychainViewModelState(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet
        )
        let listener = CovAYourValidatorListListenerSpy()
        state.setStateListener(listener)
        state.didReceiveValidators(result: .success(CovAYourValidatorFixtures.model()))
        state.didReceiveController(result: .failure(CovATestError.failed))
        XCTAssertNil(state.validatorsModel)
        state.didReceiveStashItem(result: .failure(CovATestError.failed))
        state.didReceiveLedger(result: .failure(CovATestError.failed))
        state.didReceiveRewardDestination(result: .failure(CovATestError.failed))
        state.didReceiveValidators(result: .failure(CovATestError.failed))
        state.didReceiveValidators(result: .success(nil))
        XCTAssertEqual(listener.changes, 1)
        XCTAssertTrue(listener.states.isEmpty)
    }

    // MARK: - Pool state

    func testPoolStateBuildsChangeFlowOnlyForTheNominator() throws {
        let state = YourValidatorListPoolViewModelState(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet
        )
        let listener = CovAYourValidatorListListenerSpy()
        state.setStateListener(listener)
        state.changeLocale(locale)
        XCTAssertEqual(state.locale, locale)

        state.didReceive(palletIdResult: .success(Data("py/nopls".utf8)))
        try state.didReceive(stakeInfo: CovAYourValidatorFixtures.poolMember())
        state.didReceive(nomination: nil)
        state.didReceive(stakingPool: CovAYourValidatorFixtures.stakingPool(nominator: CovAFixtures.accountId(1)))
        XCTAssertNil(state.selectValidatorsStartFlow(), "the wallet is not the pool nominator")

        state.didReceive(stakingPool: CovAYourValidatorFixtures.stakingPool(nominator: CovAFixtures.accountId(7)))
        state.didReceiveValidators(result: .success(CovAYourValidatorFixtures.model()))
        XCTAssertEqual(listener.changes, 1)

        guard case let .poolExisting(poolId, bonding) = try XCTUnwrap(state.selectValidatorsStartFlow()) else {
            return XCTFail("existing pool bonding expected")
        }
        XCTAssertEqual(poolId, 5)
        XCTAssertEqual(bonding.amount, 2)
        XCTAssertEqual(bonding.controllerAccount.accountId, CovAFixtures.accountId(7))
        XCTAssertNotEqual(bonding.stashAddress, CovAFixtures.address(7))
        guard case let .payout(rewardAddress) = bonding.rewardDestination else { return XCTFail("payout expected") }
        XCTAssertNotEqual(rewardAddress, bonding.stashAddress)

        XCTAssertNotNil(state.validatorInfoFlow(address: CovAFixtures.address(1)))
        XCTAssertNil(state.validatorInfoFlow(address: CovAFixtures.address(42)))

        state.didReceiveValidators(result: .failure(CovATestError.failed))
        state.didReceive(error: CovATestError.failed)
        state.didReceive(palletIdResult: .failure(CovATestError.failed))
        XCTAssertEqual(listener.errors.count, 3)
        state.resetState()
        XCTAssertNil(state.validatorsModel)
    }

    // MARK: - Factories

    func testFactoriesGroupValidatorsBySection() throws {
        let relayState = YourValidatorListRelaychainViewModelState(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet
        )
        relayState.didReceiveValidators(result: .success(CovAYourValidatorFixtures.model()))
        let poolState = YourValidatorListPoolViewModelState(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet
        )
        poolState.didReceiveValidators(result: .success(CovAYourValidatorFixtures.model()))
        let balance = CovAFixtures.balanceFactory()
        let factories: [YourValidatorListViewModelFactoryProtocol] = [
            YourValidatorListRelaychainViewModelFactory(balanceViewModeFactory: balance),
            YourValidatorListPoolViewModelFactory(balanceViewModeFactory: balance)
        ]
        let states: [YourValidatorListViewModelState] = [relayState, poolState]
        for (factory, state) in zip(factories, states) {
            let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state, locale: locale))
            XCTAssertEqual(viewModel.sections.map(\.status), [.stakeAllocated, .pending, .stakeNotAllocated, .unelected])
            XCTAssertTrue(viewModel.allValidatorWithoutRewards)
            XCTAssertFalse(viewModel.userCanSelectValidators)
            let active = viewModel.sections[0].validators[0]
            XCTAssertEqual(active.name, "Active")
            XCTAssertTrue(try XCTUnwrap(active.amount).contains("3"))
            XCTAssertTrue(try XCTUnwrap(active.apy?.string).hasPrefix("APY"))
            XCTAssertTrue(active.shouldHaveWarning)
            XCTAssertTrue(active.shouldHaveError)
            XCTAssertTrue(try XCTUnwrap(active.staked).contains("100"))
            XCTAssertNil(viewModel.sections[3].validators[0].apy)
            XCTAssertNil(viewModel.sections[2].validators[0].amount)
        }
        XCTAssertNil(factories[0].buildViewModel(viewModelState: poolState, locale: locale))
        XCTAssertNil(factories[1].buildViewModel(viewModelState: relayState, locale: locale))
    }

    // MARK: - Presenter

    private func makePresenter(
        state: YourValidatorListViewModelState
    ) -> (YourValidatorListPresenter, CovAYourValidatorListViewStub, CovAYourValidatorListWireframeStub, CovAYourValidatorListStrategySpy) {
        let strategy = CovAYourValidatorListStrategySpy()
        let interactor = YourValidatorListInteractor(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet,
            strategy: strategy
        )
        let wireframe = CovAYourValidatorListWireframeStub()
        let factory: YourValidatorListViewModelFactoryProtocol = state is YourValidatorListPoolViewModelState
            ? YourValidatorListPoolViewModelFactory(balanceViewModeFactory: CovAFixtures.balanceFactory())
            : YourValidatorListRelaychainViewModelFactory(balanceViewModeFactory: CovAFixtures.balanceFactory())
        let presenter = YourValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: factory,
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet,
            localizationManager: CovAFixtures.localizationManager,
            logger: Logger.shared,
            viewModelState: state
        )
        let view = CovAYourValidatorListViewStub()
        view.loadViewIfNeeded()
        presenter.view = view
        interactor.presenter = presenter
        return (presenter, view, wireframe, strategy)
    }

    func testPresenterDrivesLoadingSelectionAndChanges() throws {
        let state = YourValidatorListRelaychainViewModelState(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet
        )
        let (presenter, view, wireframe, strategy) = makePresenter(state: state)
        presenter.didLoad(view: view)
        presenter.willAppear(view: view)
        XCTAssertEqual(strategy.calls, ["setup"])
        XCTAssertEqual(view.loading, [true])

        presenter.changeValidators()
        XCTAssertTrue(wireframe.startFlows.isEmpty)

        state.didReceiveStashItem(result: .success(StashItem(stash: CovAFixtures.address(7), controller: CovAFixtures.address(8))))
        try state.didReceiveLedger(result: .success(CovAYourValidatorFixtures.ledger()))
        state.didReceiveRewardDestination(result: .success(.stash))
        presenter.changeValidators()
        XCTAssertEqual(wireframe.missingControllers, [CovAFixtures.address(8)])

        state.didReceiveController(result: .success(CovAYourValidatorFixtures.controller()))
        state.didReceiveValidators(result: .success(CovAYourValidatorFixtures.model()))
        guard case let .validatorList(viewModel) = try XCTUnwrap(view.states.last) else { return XCTFail("list expected") }
        XCTAssertTrue(viewModel.userCanSelectValidators)
        presenter.willAppear(view: view)
        XCTAssertEqual(view.loading, [true, false], "a loaded list does not show the loader again")

        presenter.changeValidators()
        XCTAssertEqual(wireframe.startFlows.count, 1)

        presenter.didSelectValidator(viewModel: viewModel.sections[0].validators[0])
        XCTAssertEqual(wireframe.infoFlows.count, 1)
        presenter.didSelectValidator(viewModel: YourValidatorViewModel(
            address: "unknown", name: nil, amount: nil, apy: nil, staked: nil, shouldHaveWarning: false, shouldHaveError: false
        ))
        XCTAssertEqual(wireframe.infoFlows.count, 1)

        presenter.didReceiveState(.loading)
        presenter.didReceiveError(error: CovATestError.failed)
        presenter.applyLocalization()
        guard case .validatorList = try XCTUnwrap(view.states.last) else { return XCTFail("localization rebuilds the list") }

        presenter.retry()
        XCTAssertEqual(strategy.calls, ["setup", "refresh"])
        presenter.applyLocalization()
        guard case .error = try XCTUnwrap(view.states.last) else { return XCTFail("no model after reset shows an error") }
    }

    func testPresenterWithoutViewSkipsMissingControllerAlert() {
        let state = YourValidatorListPoolViewModelState(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet
        )
        let (presenter, _, wireframe, _) = makePresenter(state: state)
        presenter.view = nil
        presenter.handleControllerAccountMissing("x")
        XCTAssertTrue(wireframe.missingControllers.isEmpty)
    }

    // MARK: - View controller

    func testViewControllerRendersSectionsAndForwardsActions() throws {
        let presenter = CovAYourValidatorListPresenterSpy()
        let controller = YourValidatorListViewController(presenter: presenter, localizationManager: CovAFixtures.localizationManager)
        let window = CovAViewInspector.host(controller)
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        XCTAssertEqual(Array(presenter.calls.prefix(1)), ["load"])
        XCTAssertTrue(presenter.calls.contains("appear"))

        let state = YourValidatorListRelaychainViewModelState(
            chainAsset: CovAYourValidatorFixtures.chainAsset,
            wallet: CovAYourValidatorFixtures.wallet
        )
        state.didReceiveValidators(result: .success(CovAYourValidatorFixtures.model()))
        let base = try XCTUnwrap(YourValidatorListRelaychainViewModelFactory(balanceViewModeFactory: CovAFixtures.balanceFactory())
            .buildViewModel(viewModelState: state, locale: locale))
        let viewModel = YourValidatorListViewModel(
            allValidatorWithoutRewards: true, sections: base.sections, userCanSelectValidators: true
        )
        controller.reload(state: .validatorList(viewModel: viewModel))
        let table = controller.rootView.tableView
        table.layoutIfNeeded()

        XCTAssertEqual(table.numberOfSections, 4)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        XCTAssertFalse(controller.rootView.changeValidatorsButton.isHidden)
        XCTAssertTrue(controller.rootView.emptyView.isHidden)

        for section in 0 ..< 4 {
            XCTAssertNotNil(controller.tableView(table, viewForHeaderInSection: section))
            let cell = try XCTUnwrap(
                controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: section)) as? YourValidatorTableCell
            )
            XCTAssertFalse((cell.titleLabel.text ?? "").isEmpty)
        }
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(presenter.selected.first?.address, CovAFixtures.address(4))

        controller.rootView.changeValidatorsButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(presenter.calls.contains("change"))

        let rewarded = YourValidatorListViewModel(allValidatorWithoutRewards: false, sections: base.sections, userCanSelectValidators: false)
        controller.reload(state: .validatorList(viewModel: rewarded))
        XCTAssertNotNil(controller.tableView(table, viewForHeaderInSection: 0))
        XCTAssertTrue(controller.rootView.changeValidatorsButton.isHidden)

        let empty = YourValidatorListViewModel(allValidatorWithoutRewards: false, sections: [], userCanSelectValidators: false)
        controller.reload(state: .validatorList(viewModel: empty))
        XCTAssertFalse(controller.rootView.emptyView.isHidden)

        controller.reload(state: .loading)
        XCTAssertEqual(controller.numberOfSections(in: table), 0)
        XCTAssertFalse(controller.shouldDisplayEmptyState)

        controller.reload(state: .error("No data"))
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        let errorView = try XCTUnwrap(controller.viewForEmptyState as? ErrorStateView)
        XCTAssertEqual(errorView.errorDescriptionLabel.text, "No data")
        controller.didRetry(errorView: errorView)
        XCTAssertEqual(presenter.calls.last, "retry")
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertNil(controller.tableView(table, viewForHeaderInSection: 0))
        controller.applyLocalization()
        window.isHidden = true
    }
}
