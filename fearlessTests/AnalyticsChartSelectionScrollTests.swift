import BigInt
import Foundation
import SoraFoundation
import SSFModels
import SSFUtils
import UIKit
import XCTest
@testable import fearless

/// Selecting a value on the rewards or stake chart stops the table scrolling, so dragging along the chart moves the
/// selection instead of the table. The presenter answers the selection with a synchronous reload, and the reload set
/// scrolling back on at once.
final class AnalyticsChartSelectionScrollTests: XCTestCase {
    func testSelectingARewardsChartValueKeepsTheTableStillUntilItIsUnselected() throws {
        let module = AnalyticsRewardsScrollModule()
        addTeardownBlock { module.close() }
        module.deliverRewards()
        XCTAssertTrue(module.table.isScrollEnabled)

        module.view.didSelectXValue(5)

        XCTAssertEqual(try module.loadedViewModel().chartData.amounts.filter(\.selected).count, 1, "the presenter reloaded")
        XCTAssertFalse(module.table.isScrollEnabled, "the reload that follows the selection keeps the table still")

        module.view.didUnselect()

        XCTAssertTrue(try module.loadedViewModel().chartData.amounts.allSatisfy { !$0.selected })
        XCTAssertTrue(module.table.isScrollEnabled)
    }

    func testRewardsArrivingWhileAValueIsSelectedKeepTheTableStill() throws {
        let module = AnalyticsRewardsScrollModule()
        addTeardownBlock { module.close() }
        module.deliverRewards()
        module.view.didSelectXValue(5)

        module.deliverRewards()

        XCTAssertEqual(try module.loadedViewModel().chartData.amounts.filter(\.selected).count, 1)
        XCTAssertFalse(module.table.isScrollEnabled)
    }

    func testSelectingAStakeChartValueKeepsTheTableStillUntilItIsUnselected() throws {
        let module = AnalyticsStakeScrollModule()
        addTeardownBlock { module.close() }
        try module.deliverStakeChanges()
        XCTAssertTrue(module.table.isScrollEnabled)

        module.view.didSelectXValue(1)

        XCTAssertEqual(try module.loadedViewModel().chartData.amounts.map(\.selected), [false, true, false], "the presenter reloaded")
        XCTAssertFalse(module.table.isScrollEnabled, "the reload that follows the selection keeps the table still")

        module.view.didUnselect()

        XCTAssertTrue(try module.loadedViewModel().chartData.amounts.allSatisfy { !$0.selected })
        XCTAssertTrue(module.table.isScrollEnabled)
    }
}

// MARK: - Module harness

/// Shared values for the analytics module harness: a 2-decimal staking asset, a wallet and an iPhone-sized window in
/// the host app's scene.
enum AnalyticsScrollFixtures {
    static let stash = "analytics-scroll-stash"

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    static func chainAsset() -> ChainAsset {
        AssetHubTestSupport.makeAsset(chainId: "analytics-scroll-" + UUID().uuidString)
    }

    /// A timestamp `daysAgo` days before the start of today, at ten o'clock.
    static func timestamp(daysAgo: Int) -> Int64 {
        let startOfToday = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday) ?? startOfToday
        let date = calendar.date(byAdding: .hour, value: 10, to: day) ?? day
        return Int64(date.timeIntervalSince1970)
    }

    static func host(_ controller: UIViewController) -> UIWindow {
        let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: frame)
        window.frame = frame
        window.rootViewController = controller
        window.isHidden = false
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return window
    }
}

/// The rewards analytics module (relay chain flow) with its real presenter, view model factory and view controller;
/// the interactor and wireframe do nothing.
final class AnalyticsRewardsScrollModule {
    private final class Interactor: AnalyticsRewardsInteractorInputProtocol {
        func setup() {}
        func fetchRewards(address _: AccountAddress) {}
    }

    private final class Wireframe: AnalyticsRewardsWireframeProtocol {
        func showRewardDetails(_: AnalyticsRewardDetailsModel, from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chainAsset _: ChainAsset) {}
        func showRewardPayoutsForNominator(from _: ControllerBackedProtocol?, stashAddress _: AccountAddress, chainAsset _: ChainAsset, wallet _: MetaAccountModel) {}
        func showRewardPayoutsForValidator(from _: ControllerBackedProtocol?, stashAddress _: AccountAddress, chainAsset _: ChainAsset, wallet _: MetaAccountModel) {}
    }

    let state = AnalyticsRewardsRelaychainViewModelState()
    let presenter: AnalyticsRewardsPresenter
    let view: AnalyticsRewardsViewController
    private let window: UIWindow

    var table: UITableView { view.rootView.tableView }

    init() {
        let chainAsset = AnalyticsScrollFixtures.chainAsset()
        presenter = AnalyticsRewardsPresenter(
            interactor: Interactor(),
            wireframe: Wireframe(),
            viewModelFactory: AnalyticsRewardsRelaychainViewModelFactory(
                assetInfo: chainAsset.asset.displayInfo,
                balanceViewModelFactory: StubBalanceViewModelFactory(),
                calendar: AnalyticsScrollFixtures.calendar
            ),
            viewModelState: state,
            localizationManager: LocalizationManager.shared,
            accountIsNominator: true,
            chainAsset: chainAsset,
            wallet: AccountGenerator.generateMetaAccount()
        )
        view = AnalyticsRewardsViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        presenter.view = view
        window = AnalyticsScrollFixtures.host(view)
    }

    func deliverRewards() {
        state.didReceiveStashItem(StashItem(stash: AnalyticsScrollFixtures.stash, controller: AnalyticsScrollFixtures.stash))
        state.didReceieveSubqueryData([
            reward("r1", daysAgo: 2, amount: 150),
            reward("r2", daysAgo: 1, amount: 250)
        ])
        view.view.layoutIfNeeded()
    }

    func loadedViewModel() throws -> AnalyticsRewardsViewModel {
        guard case let .loaded(viewModel) = view.viewState else {
            throw NSError(domain: "analytics-scroll", code: 1, userInfo: [NSLocalizedDescriptionKey: "not loaded"])
        }
        return viewModel
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }

    private func reward(_ eventId: String, daysAgo: Int, amount: BigUInt) -> SubqueryRewardItemData {
        SubqueryRewardItemData(
            eventId: eventId,
            timestamp: AnalyticsScrollFixtures.timestamp(daysAgo: daysAgo),
            validatorAddress: "",
            era: 0,
            stashAddress: AnalyticsScrollFixtures.stash,
            amount: amount,
            isReward: true
        )
    }
}

/// The stake analytics module with its real presenter, view model factory and view controller; the interactor and
/// wireframe do nothing.
final class AnalyticsStakeScrollModule {
    private final class Interactor: AnalyticsStakeInteractorInputProtocol {
        func setup() {}
        func fetchStakeHistory(stashAddress _: AccountAddress) {}
    }

    private final class Wireframe: AnalyticsStakeWireframeProtocol {
        func showRewardDetails(_: AnalyticsRewardDetailsModel, from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chainAsset _: ChainAsset) {}
    }

    let presenter: AnalyticsStakePresenter
    let view: AnalyticsStakeViewController
    private let window: UIWindow

    var table: UITableView { view.rootView.tableView }

    init() {
        let chainAsset = AnalyticsScrollFixtures.chainAsset()
        presenter = AnalyticsStakePresenter(
            interactor: Interactor(),
            wireframe: Wireframe(),
            viewModelFactory: AnalyticsStakeViewModelFactory(
                assetInfo: chainAsset.asset.displayInfo,
                balanceViewModelFactory: StubBalanceViewModelFactory(),
                calendar: AnalyticsScrollFixtures.calendar
            ),
            localizationManager: LocalizationManager.shared,
            wallet: AccountGenerator.generateMetaAccount(),
            chainAsset: chainAsset
        )
        view = AnalyticsStakeViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        presenter.view = view
        window = AnalyticsScrollFixtures.host(view)
    }

    func deliverStakeChanges() throws {
        presenter.didReceieve(stakeDataResult: .success([
            try change("bond", daysAgo: 3, amount: 100, accumulated: 100, type: "bonded"),
            try change("unbond", daysAgo: 2, amount: 30, accumulated: 70, type: "unbonded"),
            try change("reward", daysAgo: 1, amount: 5, accumulated: 75, type: "rewarded")
        ]))
        view.view.layoutIfNeeded()
    }

    func loadedViewModel() throws -> AnalyticsRewardsViewModel {
        guard case let .loaded(viewModel) = view.viewState else {
            throw NSError(domain: "analytics-scroll", code: 2, userInfo: [NSLocalizedDescriptionKey: "not loaded"])
        }
        return viewModel
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }

    private func change(_ eventId: String, daysAgo: Int, amount: BigUInt, accumulated: BigUInt, type: String) throws -> SubqueryStakeChangeData {
        let json = JSON.dictionaryValue([
            "id": .stringValue(eventId),
            "timestamp": .stringValue(String(AnalyticsScrollFixtures.timestamp(daysAgo: daysAgo))),
            "address": .stringValue(AnalyticsScrollFixtures.stash),
            "amount": .stringValue(String(amount)),
            "accumulatedAmount": .stringValue(String(accumulated)),
            "type": .stringValue(type)
        ])
        return try XCTUnwrap(SubqueryStakeChangeData(from: json))
    }
}
