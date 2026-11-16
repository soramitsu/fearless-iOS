import BigInt
import Foundation
import RobinHood
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovBAnRewardsInteractorStub: AnalyticsRewardsInteractorInputProtocol {
    private(set) var setupCalls = 0
    private(set) var fetchedAddresses: [AccountAddress] = []

    func setup() { setupCalls += 1 }
    func fetchRewards(address: AccountAddress) { fetchedAddresses.append(address) }
}

final class CovBAnRewardsWireframeStub: AnalyticsRewardsWireframeProtocol {
    private(set) var shownDetails: [String] = []
    private(set) var nominatorPayouts: [AccountAddress] = []
    private(set) var validatorPayouts: [AccountAddress] = []

    func showRewardDetails(
        _ rewardModel: AnalyticsRewardDetailsModel,
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    ) {
        shownDetails.append(rewardModel.eventId)
    }

    func showRewardPayoutsForNominator(
        from _: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        nominatorPayouts.append(stashAddress)
    }

    func showRewardPayoutsForValidator(
        from _: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        validatorPayouts.append(stashAddress)
    }
}

final class CovBAnRewardsStrategyStub: AnalyticsRewardsStrategy {
    private(set) var setupCalls = 0
    private(set) var fetchedAddresses: [AccountAddress] = []

    func setup() { setupCalls += 1 }
    func fetchRewards(address: AccountAddress) { fetchedAddresses.append(address) }
}

final class CovBAnRewardsStrategyOutputStub: AnalyticsRewardsRelaychainStrategyOutput {
    private(set) var subqueryData: [[SubqueryRewardItemData]?] = []
    private(set) var stashItems: [StashItem?] = []
    private(set) var errors: [Error] = []

    func didReceieveSubqueryData(_ subqueryData: [SubqueryRewardItemData]?) { self.subqueryData.append(subqueryData) }
    func didReceiveStashItem(_ stashItem: StashItem?) { stashItems.append(stashItem) }
    func didReceiveError(_ error: Error) { errors.append(error) }
}

final class CovBAnRewardsModuleTests: XCTestCase {
    private struct CovBAnModule {
        let interactor: CovBAnRewardsInteractorStub
        let wireframe: CovBAnRewardsWireframeStub
        let state: AnalyticsRewardsRelaychainViewModelState
        let presenter: AnalyticsRewardsPresenter
        let view: AnalyticsRewardsViewController
        let window: UIWindow

        var table: UITableView { view.rootView.tableView }
        var header: AnalyticsRewardsHeaderView { view.rootView.headerView }

        var loadedViewModel: AnalyticsRewardsViewModel? {
            guard case let .loaded(viewModel) = view.viewState else { return nil }
            return viewModel
        }
    }

    private var locale: Locale { CovBAnFixtures.locale }

    private func makeModule(accountIsNominator: Bool = true) -> CovBAnModule {
        let chainAsset = CovBAnFixtures.chainAsset()
        let interactor = CovBAnRewardsInteractorStub()
        let wireframe = CovBAnRewardsWireframeStub()
        let state = AnalyticsRewardsRelaychainViewModelState()
        let factory = AnalyticsRewardsRelaychainViewModelFactory(
            assetInfo: chainAsset.asset.displayInfo,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            calendar: CovBAnFixtures.calendar
        )
        let presenter = AnalyticsRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: factory,
            viewModelState: state,
            localizationManager: LocalizationManager.shared,
            accountIsNominator: accountIsNominator,
            chainAsset: chainAsset,
            wallet: CovBAnFixtures.wallet()
        )
        let view = AnalyticsRewardsViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        presenter.view = view
        let window = CovBAnFixtures.host(view)
        return CovBAnModule(
            interactor: interactor,
            wireframe: wireframe,
            state: state,
            presenter: presenter,
            view: view,
            window: window
        )
    }

    private func deliverRewards(to module: CovBAnModule) {
        module.state.didReceiveStashItem(StashItem(stash: "stash-1", controller: "controller-1"))
        module.state.didReceieveSubqueryData([
            CovBAnFixtures.reward("r1", daysAgo: 2, amount: 150),
            CovBAnFixtures.reward("r2", daysAgo: 1, amount: 250)
        ])
        module.view.view.layoutIfNeeded()
    }

    func testSetupShowsLoadingAndStartsTheInteractor() {
        let module = makeModule()

        XCTAssertEqual(module.interactor.setupCalls, 1)
        XCTAssertEqual(module.view.viewState, .loading)
        XCTAssertNotNil(module.table.refreshControl)
        XCTAssertEqual(module.view.numberOfSections(in: module.table), 0)
        XCTAssertEqual(module.view.tableView(module.table, numberOfRowsInSection: 0), 0)
        XCTAssertNil(module.view.tableView(module.table, viewForHeaderInSection: 0))
        XCTAssertEqual(module.view.tableView(module.table, heightForHeaderInSection: 0), UITableView.automaticDimension)
        XCTAssertEqual(
            module.view.localizedTitle.value(for: locale),
            R.string.localizable.stakingRewardsTitle(preferredLanguages: locale.rLanguages)
        )
        XCTAssertTrue(module.table.dataSource === module.view)
        XCTAssertTrue(module.header.periodView.delegate === module.view)
    }

    func testRewardsFillHeaderTableAndPendingRewardsRow() throws {
        let module = makeModule()
        deliverRewards(to: module)

        let viewModel = try XCTUnwrap(module.loadedViewModel)
        XCTAssertEqual(module.table.refreshControl?.isRefreshing, false)
        XCTAssertEqual(module.header.selectedPeriodLabel.text, viewModel.summaryViewModel.title)
        XCTAssertFalse(module.header.pendingRewardsView.isHidden)
        XCTAssertEqual(
            module.header.pendingRewardsView.rowContentView.titleLabel.text,
            R.string.localizable.stakingPendingRewards(preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(module.view.numberOfSections(in: module.table), 2)
        XCTAssertEqual(module.view.tableView(module.table, numberOfRowsInSection: 1), 1)

        let cell = try XCTUnwrap(
            module.view.tableView(module.table, cellForRowAt: IndexPath(row: 0, section: 0)) as? AnalyticsHistoryCell
        )
        XCTAssertEqual(cell.historyView.titleLabel.text, R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(cell.historyView.tokenAmountLabel.text, "+2.5")
        XCTAssertEqual(cell.historyView.daysLeftLabel.textColor, R.color.colorStrokeGray())

        let header = try XCTUnwrap(module.view.tableView(module.table, viewForHeaderInSection: 0) as? AnalyticsSectionHeader)
        XCTAssertEqual(header.label.text, viewModel.sections[0].title)
        XCTAssertEqual(module.view.tableView(module.table, heightForHeaderInSection: 0), UITableView.automaticDimension)
    }

    func testSelectingRowsAndPendingRewardsRouteThroughTheWireframe() {
        let module = makeModule()
        deliverRewards(to: module)

        module.view.tableView(module.table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(module.wireframe.shownDetails, ["r1"])

        module.header.pendingRewardsView.sendActions(for: .touchUpInside)
        XCTAssertEqual(module.wireframe.nominatorPayouts, ["stash-1"])
        XCTAssertTrue(module.wireframe.validatorPayouts.isEmpty)

        let validatorModule = makeModule(accountIsNominator: false)
        deliverRewards(to: validatorModule)
        validatorModule.presenter.handlePendingRewardsAction()
        XCTAssertEqual(validatorModule.wireframe.validatorPayouts, ["stash-1"])
        XCTAssertTrue(validatorModule.wireframe.nominatorPayouts.isEmpty)
    }

    func testPendingRewardsNeedAStashAddress() {
        let module = makeModule()
        module.presenter.handlePendingRewardsAction()
        module.presenter.reload()

        XCTAssertTrue(module.wireframe.nominatorPayouts.isEmpty)
        XCTAssertTrue(module.interactor.fetchedAddresses.isEmpty)
        XCTAssertEqual(module.view.viewState, .loading)
    }

    func testChartSelectionHighlightsTheBarAndKeepsTheTableStillUntilUnselect() throws {
        let module = makeModule()
        deliverRewards(to: module)

        module.view.didSelectXValue(5)
        XCTAssertFalse(module.table.isScrollEnabled, "The selected-model reload keeps the table still (497e99a18)")
        XCTAssertFalse(module.view.animateChartOnReload)
        let selected = try XCTUnwrap(module.loadedViewModel)
        XCTAssertEqual(selected.chartData.amounts.filter(\.selected).count, 1)
        XCTAssertEqual(selected.summaryViewModel.tokenAmount, "2.5")

        module.view.didUnselect()
        XCTAssertTrue(module.table.isScrollEnabled)
        XCTAssertTrue(module.view.animateChartOnReload)
        let unselected = try XCTUnwrap(module.loadedViewModel)
        XCTAssertTrue(unselected.chartData.amounts.allSatisfy { !$0.selected })
        XCTAssertEqual(unselected.summaryViewModel.tokenAmount, "4")
    }

    func testPeriodButtonsSelectThePeriod() throws {
        let module = makeModule()
        deliverRewards(to: module)

        module.view.didSelect(period: .month)
        XCTAssertEqual(try XCTUnwrap(module.loadedViewModel).selectedPeriod, .month)
        XCTAssertEqual(try XCTUnwrap(module.loadedViewModel).chartData.amounts.count, 30)

        let buttons = CovBAnFixtures.allSubviews(of: AnalyticsMagentaButton<AnalyticsPeriod>.self, in: module.header.periodView)
        XCTAssertEqual(buttons.map(\.model), AnalyticsPeriod.allCases)
        let yearButton = try XCTUnwrap(buttons.first { $0.model == .year })
        yearButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(try XCTUnwrap(module.loadedViewModel).selectedPeriod, .year)
        XCTAssertEqual(buttons.filter(\.isSelected).map(\.model), [.year])
        XCTAssertEqual(
            buttons.map { $0.imageWithTitleView?.title },
            AnalyticsPeriod.allCases.map { $0.title(for: module.header.locale) as String? }
        )
    }

    func testRefreshReloadsTheStashHistoryAndRetryAfterError() throws {
        let module = makeModule()
        deliverRewards(to: module)

        module.table.refreshControl?.sendActions(for: .valueChanged)
        XCTAssertEqual(module.interactor.fetchedAddresses, ["stash-1"])
        XCTAssertEqual(module.view.viewState, .loading)

        module.view.reload(viewState: .error("Boom"))
        XCTAssertTrue(module.view.shouldDisplayEmptyState)
        let errorView = try XCTUnwrap(module.view.viewForEmptyState as? ErrorStateView)
        XCTAssertEqual(errorView.errorDescriptionLabel.text, "Boom")
        XCTAssertEqual(module.view.numberOfSections(in: module.table), 0)

        module.view.didRetry(errorView: errorView)
        XCTAssertEqual(module.interactor.fetchedAddresses, ["stash-1", "stash-1"])
        XCTAssertFalse(module.view.shouldDisplayEmptyState)
        XCTAssertNil(module.view.viewForEmptyState)
    }

    func testEmptyHistoryShowsTheEmptyStateCell() throws {
        let module = makeModule()
        module.state.didReceieveSubqueryData([CovBAnFixtures.reward("slash", daysAgo: 1, amount: 9, isReward: false)])

        let viewModel = try XCTUnwrap(module.loadedViewModel)
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertEqual(module.view.numberOfSections(in: module.table), 1)
        XCTAssertEqual(module.view.tableView(module.table, numberOfRowsInSection: 0), 1)
        let cell = try XCTUnwrap(
            module.view.tableView(module.table, cellForRowAt: IndexPath(row: 0, section: 0)) as? EmptyStateViewCell
        )
        XCTAssertEqual(cell.emptyView.title, viewModel.emptyListDescription)
        XCTAssertNil(module.view.tableView(module.table, viewForHeaderInSection: 0))
        XCTAssertEqual(module.view.tableView(module.table, heightForHeaderInSection: 0), 0)
        XCTAssertTrue(module.header.pendingRewardsView.isHidden == false)
    }

    func testLocalizationAndErrorsKeepTheLoadedState() throws {
        let module = makeModule()
        deliverRewards(to: module)
        let before = try XCTUnwrap(module.loadedViewModel)

        module.presenter.applyLocalization()
        module.view.applyLocalization()
        module.presenter.provideError(CovBAnError(code: 1))

        XCTAssertEqual(module.loadedViewModel, before)
        XCTAssertEqual(module.header.locale, module.view.selectedLocale)
    }

    func testInteractorForwardsToTheStrategy() {
        let strategy = CovBAnRewardsStrategyStub()
        let interactor = AnalyticsRewardsInteractor(
            strategy: strategy,
            chainAsset: CovBAnFixtures.chainAsset(),
            wallet: CovBAnFixtures.wallet()
        )

        interactor.setup()
        interactor.fetchRewards(address: "stash-2")

        XCTAssertEqual(strategy.setupCalls, 1)
        XCTAssertEqual(strategy.fetchedAddresses, ["stash-2"])
    }

    func testRelaychainStrategyForwardsStashItemsAndErrors() {
        let output = CovBAnRewardsStrategyOutputStub()
        let strategy = AnalyticsRewardsRelaychainStrategy(
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(),
            operationManager: OperationManager(),
            logger: nil,
            chainAsset: CovBAnFixtures.chainAsset(),
            wallet: CovBAnFixtures.wallet(),
            output: output
        )

        strategy.handleStashItem(result: .success(StashItem(stash: "stash-3", controller: "c")), for: "stash-3")
        strategy.handleStashItem(result: .success(nil), for: "stash-3")
        strategy.handleStashItem(result: .failure(CovBAnError(code: 4)), for: "stash-3")
        strategy.fetchRewards(address: "stash-3")

        XCTAssertEqual(output.stashItems, [StashItem(stash: "stash-3", controller: "c"), nil])
        XCTAssertEqual(output.errors.compactMap { $0 as? CovBAnError }, [CovBAnError(code: 4)])
        XCTAssertTrue(output.subqueryData.isEmpty, "A chain without a staking API fetches nothing")
    }

    func testRelaychainStrategySetupSubscribesToTheWalletStash() {
        let output = CovBAnRewardsStrategyOutputStub()
        let strategy = AnalyticsRewardsRelaychainStrategy(
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(),
            operationManager: OperationManager(),
            logger: nil,
            chainAsset: CovBAnFixtures.chainAsset(),
            wallet: CovBAnFixtures.wallet(),
            output: output
        )

        strategy.setup()

        XCTAssertTrue(CovBAnFixtures.spin { !output.stashItems.isEmpty })
        XCTAssertNil(output.stashItems.first ?? nil, "The wallet has no stash stored yet")
    }

    func testViewFactoryBuildsTheRelaychainModule() throws {
        let view = AnalyticsRewardsViewFactory.createView(
            flow: .relaychain,
            accountIsNominator: true,
            chainAsset: CovBAnFixtures.chainAsset(),
            wallet: CovBAnFixtures.wallet()
        )

        let controller = try XCTUnwrap(view?.controller as? AnalyticsRewardsViewController)
        XCTAssertFalse(controller.isViewLoaded)
        XCTAssertTrue(controller.presenter.view === controller)
        XCTAssertTrue(controller.presenter.accountIsNominator)
        XCTAssertTrue(controller.presenter.interactor is AnalyticsRewardsInteractor)
        XCTAssertTrue(controller.presenter.wireframe is AnalyticsRewardsWireframe)
    }

    func testWireframePresentsRewardDetailsAndSkipsPayoutsWithoutConnection() throws {
        let host = CovBVmValidatorView()
        let window = CovBAnFixtures.host(host)
        let chainAsset = CovBAnFixtures.chainAsset()
        let wallet = CovBAnFixtures.wallet()
        let wireframe = AnalyticsRewardsWireframe()

        wireframe.showRewardPayoutsForNominator(from: host, stashAddress: "stash", chainAsset: chainAsset, wallet: wallet)
        wireframe.showRewardPayoutsForValidator(from: host, stashAddress: "stash", chainAsset: chainAsset, wallet: wallet)
        XCTAssertNil(host.presentedViewController)

        wireframe.showRewardDetails(
            CovBAnFixtures.reward("1-1", daysAgo: 1, amount: 5),
            from: host,
            wallet: wallet,
            chainAsset: chainAsset
        )
        CovBAnFixtures.spin { host.presentedViewController != nil }
        let navigation = try XCTUnwrap(host.presentedViewController as? UINavigationController)
        XCTAssertTrue(navigation.viewControllers.first is AnalyticsRewardDetailsViewController)
        XCTAssertNotNil(window.rootViewController)
    }
}
