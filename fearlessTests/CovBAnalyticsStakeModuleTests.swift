import BigInt
import Foundation
import RobinHood
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovBAnStakeInteractorStub: AnalyticsStakeInteractorInputProtocol {
    private(set) var setupCalls = 0
    private(set) var historyRequests: [AccountAddress] = []

    func setup() { setupCalls += 1 }
    func fetchStakeHistory(stashAddress: AccountAddress) { historyRequests.append(stashAddress) }
}

final class CovBAnStakeWireframeStub: AnalyticsStakeWireframeProtocol {
    private(set) var shownDetails: [String] = []

    func showRewardDetails(
        _ rewardModel: AnalyticsRewardDetailsModel,
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset
    ) {
        shownDetails.append(rewardModel.eventId)
    }
}

final class CovBAnStakeOutputStub: AnalyticsStakeInteractorOutputProtocol {
    private(set) var stakeResults: [Result<[SubqueryStakeChangeData], Error>] = []
    private(set) var stashResults: [Result<StashItem?, Error>] = []

    func didReceieve(stakeDataResult: Result<[SubqueryStakeChangeData], Error>) { stakeResults.append(stakeDataResult) }
    func didReceiveStashItem(result: Result<StashItem?, Error>) { stashResults.append(result) }
}

final class CovBAnStakeModuleTests: XCTestCase {
    private struct CovBAnModule {
        let interactor: CovBAnStakeInteractorStub
        let wireframe: CovBAnStakeWireframeStub
        let presenter: AnalyticsStakePresenter
        let view: AnalyticsStakeViewController
        let window: UIWindow

        var table: UITableView { view.rootView.tableView }
        var header: AnalyticsStakeHeaderView { view.rootView.headerView }

        var loadedViewModel: AnalyticsRewardsViewModel? {
            guard case let .loaded(viewModel) = view.viewState else { return nil }
            return viewModel
        }
    }

    private var locale: Locale { CovBAnFixtures.locale }

    private func makeModule() -> CovBAnModule {
        let chainAsset = CovBAnFixtures.chainAsset()
        let interactor = CovBAnStakeInteractorStub()
        let wireframe = CovBAnStakeWireframeStub()
        let factory = AnalyticsStakeViewModelFactory(
            assetInfo: chainAsset.asset.displayInfo,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            calendar: CovBAnFixtures.calendar
        )
        let presenter = AnalyticsStakePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: factory,
            localizationManager: LocalizationManager.shared,
            wallet: CovBAnFixtures.wallet(),
            chainAsset: chainAsset
        )
        let view = AnalyticsStakeViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        presenter.view = view
        let window = CovBAnFixtures.host(view)
        return CovBAnModule(interactor: interactor, wireframe: wireframe, presenter: presenter, view: view, window: window)
    }

    private func changes() throws -> [SubqueryStakeChangeData] {
        [
            try CovBAnFixtures.stakeChange("bond", daysAgo: 3, amount: 100, accumulated: 100, type: "bonded"),
            try CovBAnFixtures.stakeChange("unbond", daysAgo: 2, amount: 30, accumulated: 70, type: "unbonded"),
            try CovBAnFixtures.stakeChange("reward", daysAgo: 1, amount: 5, accumulated: 75, type: "rewarded")
        ]
    }

    func testSetupShowsLoadingAndStashLoadsTheHistory() {
        let module = makeModule()

        XCTAssertEqual(module.interactor.setupCalls, 1)
        XCTAssertEqual(module.view.viewState, .loading)
        XCTAssertEqual(
            module.view.localizedTitle.value(for: locale),
            R.string.localizable.stakingStake(preferredLanguages: locale.rLanguages)
        )

        module.presenter.didReceiveStashItem(result: .success(StashItem(stash: "stash-9", controller: "c")))
        module.presenter.didReceiveStashItem(result: .success(nil))
        module.presenter.didReceiveStashItem(result: .failure(CovBAnError(code: 1)))
        XCTAssertEqual(module.interactor.historyRequests, ["stash-9"])
        XCTAssertEqual(module.view.viewState, .loading)
    }

    func testStakeHistoryFillsHeaderAndTable() throws {
        let module = makeModule()
        module.presenter.didReceieve(stakeDataResult: .success(try changes()))
        module.view.view.layoutIfNeeded()

        let viewModel = try XCTUnwrap(module.loadedViewModel)
        XCTAssertEqual(module.header.selectedPeriodLabel.text, viewModel.summaryViewModel.title)
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "0.75")
        XCTAssertEqual(module.view.numberOfSections(in: module.table), 3)
        let cell = try XCTUnwrap(
            module.view.tableView(module.table, cellForRowAt: IndexPath(row: 0, section: 1)) as? AnalyticsHistoryCell
        )
        XCTAssertEqual(cell.historyView.tokenAmountLabel.text, "-0.3")
        XCTAssertEqual(cell.historyView.titleLabel.text, R.string.localizable.stakingUnbond_v190(preferredLanguages: locale.rLanguages))

        module.view.tableView(module.table, didSelectRowAt: IndexPath(row: 0, section: 2))
        XCTAssertEqual(module.wireframe.shownDetails, ["bond"])
    }

    func testChartSelectionPeriodAndUnselect() throws {
        let module = makeModule()
        module.presenter.didReceieve(stakeDataResult: .success(try changes()))

        module.view.didSelectXValue(1)
        XCTAssertFalse(module.table.isScrollEnabled, "The selected-model reload keeps the table still (497e99a18)")
        XCTAssertEqual(try XCTUnwrap(module.loadedViewModel).summaryViewModel.tokenAmount, "0.7")
        XCTAssertEqual(try XCTUnwrap(module.loadedViewModel).chartData.amounts.map(\.selected), [false, true, false])

        module.view.didUnselect()
        XCTAssertTrue(module.table.isScrollEnabled)
        XCTAssertEqual(try XCTUnwrap(module.loadedViewModel).summaryViewModel.tokenAmount, "0.75")

        module.view.didSelect(period: .all)
        XCTAssertEqual(try XCTUnwrap(module.loadedViewModel).selectedPeriod, .all)
        let buttons = CovBAnFixtures.allSubviews(of: AnalyticsMagentaButton<AnalyticsPeriod>.self, in: module.header.periodView)
        XCTAssertEqual(buttons.filter(\.isSelected).map(\.model), [.all])
    }

    func testFailureShowsTheErrorAndRetryRestartsTheSubscription() throws {
        let module = makeModule()
        module.presenter.didReceieve(stakeDataResult: .failure(CovBAnError(code: 2)))

        let message = R.string.localizable.commonErrorNoDataRetrieved(preferredLanguages: module.presenter.selectedLocale.rLanguages)
        XCTAssertEqual(module.view.viewState, .error(message))
        XCTAssertTrue(module.view.shouldDisplayEmptyState)
        let errorView = try XCTUnwrap(module.view.viewForEmptyState as? ErrorStateView)
        XCTAssertEqual(errorView.errorDescriptionLabel.text, message)

        module.view.didRetry(errorView: errorView)
        XCTAssertEqual(module.interactor.setupCalls, 2)
        XCTAssertEqual(module.view.viewState, .loading)

        module.table.refreshControl?.sendActions(for: .valueChanged)
        XCTAssertEqual(module.interactor.setupCalls, 3)
    }

    func testUpdatesBeforeDataAndLocalizationKeepState() throws {
        let module = makeModule()
        module.presenter.didSelectPeriod(.month)
        module.presenter.didSelectXValue(0)
        module.presenter.didUnselectXValue()
        XCTAssertEqual(module.view.viewState, .loading)

        module.presenter.didReceieve(stakeDataResult: .success(try changes()))
        let before = try XCTUnwrap(module.loadedViewModel)
        XCTAssertEqual(before.selectedPeriod, .month)
        module.presenter.applyLocalization()
        XCTAssertEqual(module.loadedViewModel, before)
    }

    func testHeaderBindsSummaryAndLocalizesHistoryTitle() {
        let header = AnalyticsStakeHeaderView()
        header.bind(summaryViewModel: AnalyticsSummaryRewardViewModel(title: "Nov 2026", tokenAmount: "5 TST", usdAmount: "$10"))
        XCTAssertEqual(header.selectedPeriodLabel.text, "Nov 2026")

        header.locale = Locale(identifier: "ja_JP")
        XCTAssertEqual(header.periodView.locale, Locale(identifier: "ja_JP"))
        let labels = CovBAnFixtures.allSubviews(of: UILabel.self, in: header).compactMap(\.text)
        XCTAssertTrue(labels.contains("5 TST"))
        XCTAssertTrue(labels.contains("$10"))
        XCTAssertTrue(labels.contains(R.string.localizable.walletHistoryTitle_v190(preferredLanguages: Locale(identifier: "ja_JP").rLanguages)))
    }

    func testInteractorForwardsStashAndIgnoresHistoryWithoutStakingApi() throws {
        let output = CovBAnStakeOutputStub()
        let interactor = AnalyticsStakeInteractor(
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(),
            operationManager: OperationManager(),
            selectedAccountAddress: "account",
            chainAsset: CovBAnFixtures.chainAsset()
        )
        interactor.presenter = output

        interactor.handleStashItem(result: .success(StashItem(stash: "s", controller: "c")), for: "account")
        interactor.handleStashItem(result: .failure(CovBAnError(code: 5)), for: "account")
        interactor.fetchStakeHistory(stashAddress: "s")

        XCTAssertEqual(output.stashResults.count, 2)
        XCTAssertEqual(try output.stashResults[0].get(), StashItem(stash: "s", controller: "c"))
        XCTAssertThrowsError(try output.stashResults[1].get())
        XCTAssertTrue(output.stakeResults.isEmpty)

        interactor.setup()
        XCTAssertTrue(CovBAnFixtures.spin { output.stashResults.count == 3 })
        let last = try XCTUnwrap(output.stashResults.last)
        XCTAssertNil(try last.get())
    }

    func testViewFactoryAndWireframe() throws {
        let chainAsset = CovBAnFixtures.chainAsset()
        let wallet = CovBAnFixtures.wallet()
        let view = try XCTUnwrap(AnalyticsStakeViewFactory.createView(with: wallet, chainAsset: chainAsset))
        let controller = try XCTUnwrap(view.controller as? AnalyticsStakeViewController)
        XCTAssertTrue(controller.presenter.view === controller)
        XCTAssertTrue(controller.presenter.interactor is AnalyticsStakeInteractor)
        XCTAssertTrue(controller.presenter.wireframe is AnalyticsStakeWireframe)

        let host = CovBVmValidatorView()
        let window = CovBAnFixtures.host(host)
        AnalyticsStakeWireframe().showRewardDetails(
            try CovBAnFixtures.stakeChange("5-1", daysAgo: 1, amount: 1, accumulated: 1, type: "bonded"),
            from: host,
            wallet: wallet,
            chainAsset: chainAsset
        )
        CovBAnFixtures.spin { host.presentedViewController != nil }
        let navigation = try XCTUnwrap(host.presentedViewController as? UINavigationController)
        XCTAssertTrue(navigation.viewControllers.first is AnalyticsRewardDetailsViewController)
        XCTAssertTrue(window.rootViewController === host)
    }
}
