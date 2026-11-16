import BigInt
import SSFUtils
import Foundation
import SoraFoundation
import SSFModels
import XCTest
@testable import fearless

final class CovBAnRewardsViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    private func factory() -> AnalyticsRewardsViewModelFactory {
        AnalyticsRewardsViewModelFactory(
            assetInfo: CovBAnFixtures.asset().displayInfo,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            calendar: CovBAnFixtures.calendar
        )
    }

    private func weeklyData() -> [SubqueryRewardItemData] {
        [
            CovBAnFixtures.reward("r1", daysAgo: 2, amount: 150),
            CovBAnFixtures.reward("r2", daysAgo: 1, amount: 250),
            CovBAnFixtures.reward("slash", daysAgo: 1, amount: 999, isReward: false)
        ]
    }

    private func dayTitle(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "MMM d"
        let date = Date(timeIntervalSince1970: TimeInterval(CovBAnFixtures.timestamp(daysAgo: daysAgo)))
        return formatter.string(from: date).uppercased()
    }

    func testWeeklyRewardsGroupIntoDailyBarsSummaryAndDaySections() {
        let viewModel = factory().createViewModel(
            from: weeklyData(),
            priceData: nil,
            period: .week,
            selectedChartIndex: nil,
            hasPendingRewards: true
        ).value(for: locale)

        XCTAssertEqual(viewModel.selectedPeriod, .week)
        XCTAssertTrue(viewModel.hasPendingRewards)
        XCTAssertFalse(viewModel.isEmpty)
        XCTAssertEqual(viewModel.chartData.amounts.count, 7)
        let filled = viewModel.chartData.amounts.enumerated().filter { $0.element.filled }
        XCTAssertEqual(filled.map { $0.offset }, [4, 5])
        XCTAssertEqual(filled.map { $0.element.value }, [1.5, 2.5])
        XCTAssertTrue(viewModel.chartData.amounts.filter { !$0.filled }.allSatisfy { $0.value == 2.5 / 50.0 })
        XCTAssertTrue(viewModel.chartData.amounts.allSatisfy { !$0.selected })
        XCTAssertEqual(viewModel.chartData.bottomYValue, "0")
        XCTAssertEqual(viewModel.chartData.averageAmountValue ?? 0, 4.0 / 7.0, accuracy: 1e-9)
        let average = Decimal(4.0 / 7.0).description
        XCTAssertEqual(
            viewModel.chartData.averageAmountText,
            R.string.localizable.stakingAnalyticsAvg(average, preferredLanguages: locale.rLanguages)
        )
        XCTAssertEqual(viewModel.chartData.xAxisValues.count, 3)

        let range = AnalyticsPeriod.week.dateRangeTillNow(startDate: Date(), endDate: Date(), calendar: CovBAnFixtures.calendar)
        let intervalFormatter = DateIntervalFormatter()
        intervalFormatter.dateTemplate = "MMM d-d, yyyy"
        intervalFormatter.locale = locale
        XCTAssertEqual(viewModel.summaryViewModel.title, intervalFormatter.string(from: range.0, to: range.1))
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "4")
        XCTAssertNil(viewModel.summaryViewModel.usdAmount)

        XCTAssertEqual(viewModel.sections.map(\.title), [dayTitle(daysAgo: 1), dayTitle(daysAgo: 2)])
        XCTAssertEqual(viewModel.sections.map(\.items.count), [1, 1])
        let newest = viewModel.sections[0].items[0]
        XCTAssertEqual(newest.rawModel.eventId, "r2")
        XCTAssertEqual(newest.viewModel.addressOrName, R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(newest.viewModel.daysLeftText.string, R.string.localizable.commonStaking(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(newest.viewModel.tokenAmountText, "+2.5")
        let txFormatter = DateFormatter.txHistory.value(for: locale)
        let date = Date(timeIntervalSince1970: TimeInterval(CovBAnFixtures.timestamp(daysAgo: 1)))
        XCTAssertEqual(newest.viewModel.usdAmountText, txFormatter.string(from: date))
        XCTAssertNil(newest.viewModel.timeInterval)
        XCTAssertEqual(
            viewModel.emptyListDescription,
            R.string.localizable.stakingAnalyticsRewardsEmptyMessage(preferredLanguages: locale.rLanguages)
        )
    }

    func testSelectedBarDrivesSummaryAndSectionsAndHighlightsOnlyThatBar() {
        let viewModel = factory().createViewModel(
            from: weeklyData(),
            priceData: CovBAnFixtures.priceData("3"),
            period: .week,
            selectedChartIndex: 5,
            hasPendingRewards: false
        ).value(for: locale)

        XCTAssertFalse(viewModel.hasPendingRewards)
        XCTAssertEqual(viewModel.chartData.amounts[5], ChartAmount(value: 2.5, selected: true, filled: true))
        XCTAssertEqual(viewModel.chartData.amounts.filter(\.selected).count, 1)
        XCTAssertEqual(viewModel.chartData.amounts.filter(\.filled).count, 1)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.locale = locale
        let day = CovBAnFixtures.calendar.startOfDay(
            for: Date(timeIntervalSince1970: TimeInterval(CovBAnFixtures.timestamp(daysAgo: 1)))
        )
        XCTAssertEqual(viewModel.summaryViewModel.title, formatter.string(from: day))
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "2.5")
        XCTAssertEqual(viewModel.summaryViewModel.usdAmount, "3")
        XCTAssertEqual(viewModel.sections.count, 1)
        XCTAssertEqual(viewModel.sections[0].items.map(\.rawModel.eventId), ["r2"])
    }

    func testEmptyBarSelectionShowsZeroAndNoSections() {
        let viewModel = factory().createViewModel(
            from: weeklyData(),
            priceData: nil,
            period: .week,
            selectedChartIndex: 0,
            hasPendingRewards: true
        ).value(for: locale)

        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "0")
        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertTrue(viewModel.isEmpty)
    }

    func testOutOfRangeSelectionFallsBackToPeriodTotalsAndUnfillsEveryBar() {
        let viewModel = factory().createViewModel(
            from: weeklyData(),
            priceData: nil,
            period: .week,
            selectedChartIndex: 99,
            hasPendingRewards: true
        ).value(for: locale)

        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "4")
        XCTAssertEqual(viewModel.sections.count, 2)
        XCTAssertTrue(viewModel.chartData.amounts.allSatisfy { !$0.filled && !$0.selected })
    }

    func testMonthlyRewardsUseThirtyDailyBarsAndDropOlderRewards() {
        let data = [
            CovBAnFixtures.reward("old", daysAgo: 45, amount: 700),
            CovBAnFixtures.reward("recent", daysAgo: 3, amount: 100)
        ]
        let viewModel = factory().createViewModel(
            from: data,
            priceData: nil,
            period: .month,
            selectedChartIndex: nil,
            hasPendingRewards: true
        ).value(for: locale)

        XCTAssertEqual(viewModel.chartData.amounts.count, 30)
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "1")
        XCTAssertEqual(viewModel.sections.flatMap(\.items).map(\.rawModel.eventId), ["recent"])
    }

    func testYearlyRewardsGroupByMonthIntoTwelveBars() {
        let data = [
            CovBAnFixtures.reward("r1", daysAgo: 40, amount: 150),
            CovBAnFixtures.reward("r2", daysAgo: 1, amount: 250)
        ]
        let viewModel = factory().createViewModel(
            from: data,
            priceData: nil,
            period: .year,
            selectedChartIndex: nil,
            hasPendingRewards: true
        ).value(for: locale)

        XCTAssertEqual(viewModel.chartData.amounts.count, 12)
        XCTAssertEqual(viewModel.chartData.amounts.filter(\.filled).map(\.value).reduce(0, +), 4.0, accuracy: 1e-9)
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = "yyyy"
        formatter.locale = locale
        let range = AnalyticsPeriod.year.dateRangeTillNow(startDate: Date(), endDate: Date(), calendar: CovBAnFixtures.calendar)
        XCTAssertEqual(viewModel.summaryViewModel.title, formatter.string(from: range.0, to: range.1))
        XCTAssertEqual(viewModel.sections.count, 2)
    }

    func testAllTimeRewardsUseOneBarPerMonthSinceTheFirstReward() {
        let data = [
            CovBAnFixtures.reward("r1", daysAgo: 70, amount: 150),
            CovBAnFixtures.reward("r2", daysAgo: 1, amount: 250)
        ]
        let viewModel = factory().createViewModel(
            from: data,
            priceData: nil,
            period: .all,
            selectedChartIndex: nil,
            hasPendingRewards: true
        ).value(for: locale)

        let first = Date(timeIntervalSince1970: TimeInterval(data[0].timestamp))
        let last = Date(timeIntervalSince1970: TimeInterval(data[1].timestamp))
        let months = CovBAnFixtures.calendar.dateComponents([.month], from: first, to: last).month ?? 0
        XCTAssertEqual(viewModel.chartData.amounts.count, months + 1)
        XCTAssertEqual(viewModel.chartData.amounts.filter(\.filled).map(\.value).reduce(0, +), 4.0, accuracy: 1e-9)
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "4")
    }

    func testNoRewardsGiveAnEmptyChartAndEmptyList() {
        let viewModel = factory().createViewModel(
            from: [],
            priceData: nil,
            period: .week,
            selectedChartIndex: nil,
            hasPendingRewards: true
        ).value(for: locale)

        XCTAssertTrue(viewModel.chartData.amounts.isEmpty)
        XCTAssertTrue(viewModel.chartData.averageAmountValue?.isNaN ?? false)
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "0")
    }

    func testChartAmountsGiveEmptyBarsAFiftiethOfTheTallestBar() {
        let amounts = factory().calculateChartAmounts(chartDoubles: [2, 0, 4])
        XCTAssertEqual(amounts, [
            ChartAmount(value: 2, selected: false, filled: true),
            ChartAmount(value: 4.0 / 50.0, selected: false, filled: false),
            ChartAmount(value: 4, selected: false, filled: true)
        ])
        XCTAssertEqual(factory().calculateChartAmounts(chartDoubles: []), [])
    }

    func testRewardItemConformsToAnalyticsModels() {
        let reward = CovBAnFixtures.reward("r", daysAgo: 1, amount: 42)
        XCTAssertEqual(reward.amountInChart, 42)
        XCTAssertEqual(reward.amountInHistory, 42)
        XCTAssertEqual(reward.amountSign, .plus)
        XCTAssertEqual(reward.date, Date(timeIntervalSince1970: TimeInterval(reward.timestamp)))
        XCTAssertEqual(
            reward.typeText(locale: locale),
            R.string.localizable.stakingRewardDetailsReward(preferredLanguages: locale.rLanguages)
        )
    }
}

final class CovBAnRelaychainViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    private final class CovBAnOtherState: AnalyticsRewardsViewModelState {
        var stateListener: AnalyticsRewardsModelStateListener?
        var historyAddress: String? { nil }
        var hasPendingRewards: Bool { false }
        func setStateListener(_ stateListener: AnalyticsRewardsModelStateListener?) {
            self.stateListener = stateListener
        }
    }

    private final class CovBAnListener: AnalyticsRewardsModelStateListener {
        private(set) var provideCalls = 0
        private(set) var errors: [Error] = []
        func provideRewardsViewModel() { provideCalls += 1 }
        func provideError(_ error: Error) { errors.append(error) }
    }

    private func factory() -> AnalyticsRewardsRelaychainViewModelFactory {
        AnalyticsRewardsRelaychainViewModelFactory(
            assetInfo: CovBAnFixtures.asset().displayInfo,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            calendar: CovBAnFixtures.calendar
        )
    }

    func testStateWithoutDataOrOfAnotherFlowGivesNoViewModel() {
        let state = AnalyticsRewardsRelaychainViewModelState()
        XCTAssertNil(factory().createViewModel(viewModelState: state, priceData: nil, period: .week, selectedChartIndex: nil, locale: locale))
        XCTAssertNil(
            factory().createViewModel(viewModelState: CovBAnOtherState(), priceData: nil, period: .week, selectedChartIndex: nil, locale: locale)
        )
    }

    func testStateNotifiesListenerAndExposesStashAndPendingRewards() {
        let state = AnalyticsRewardsRelaychainViewModelState()
        let listener = CovBAnListener()
        state.setStateListener(listener)
        XCTAssertTrue(state.hasPendingRewards)
        XCTAssertNil(state.historyAddress)

        state.didReceiveStashItem(StashItem(stash: "stash-a", controller: "controller-a"))
        XCTAssertEqual(state.historyAddress, "stash-a")
        XCTAssertEqual(state.stashItem, StashItem(stash: "stash-a", controller: "controller-a"))

        state.didReceieveSubqueryData([CovBAnFixtures.reward("r", daysAgo: 1, amount: 1)])
        XCTAssertEqual(listener.provideCalls, 1)
        XCTAssertEqual(state.subqueryData?.map(\.eventId), ["r"])

        state.didReceiveError(CovBAnError(code: 3))
        XCTAssertEqual(listener.errors.compactMap { $0 as? CovBAnError }, [CovBAnError(code: 3)])
    }

    func testRelaychainStateBuildsWeeklyViewModelWithPendingRewards() {
        let state = AnalyticsRewardsRelaychainViewModelState()
        state.didReceieveSubqueryData([
            CovBAnFixtures.reward("r1", daysAgo: 2, amount: 150),
            CovBAnFixtures.reward("r2", daysAgo: 1, amount: 250),
            CovBAnFixtures.reward("slash", daysAgo: 1, amount: 999, isReward: false)
        ])

        let viewModel = try? XCTUnwrap(
            factory().createViewModel(viewModelState: state, priceData: CovBAnFixtures.priceData(), period: .week, selectedChartIndex: nil, locale: locale)
        )

        XCTAssertEqual(viewModel?.hasPendingRewards, true)
        XCTAssertEqual(viewModel?.summaryViewModel.tokenAmount, "4")
        XCTAssertEqual(viewModel?.summaryViewModel.usdAmount, "2")
        XCTAssertEqual(viewModel?.chartData.amounts.filter(\.filled).map(\.value), [1.5, 2.5])
        XCTAssertEqual(viewModel?.sections.flatMap(\.items).map(\.rawModel.eventId), ["r2", "r1"])
        XCTAssertEqual(
            viewModel?.sections.first?.items.first?.viewModel.addressOrName,
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
        )
    }

    func testRelaychainSelectionYearAndAllPeriods() {
        let state = AnalyticsRewardsRelaychainViewModelState()
        let data = [
            CovBAnFixtures.reward("r1", daysAgo: 70, amount: 150),
            CovBAnFixtures.reward("r2", daysAgo: 1, amount: 250)
        ]
        state.didReceieveSubqueryData(data)

        let selected = factory().createViewModel(viewModelState: state, priceData: nil, period: .week, selectedChartIndex: 5, locale: locale)
        XCTAssertEqual(selected?.summaryViewModel.tokenAmount, "2.5")
        XCTAssertEqual(selected?.sections.flatMap(\.items).map(\.rawModel.eventId), ["r2"])
        XCTAssertEqual(selected?.chartData.amounts.filter(\.selected).count, 1)

        let emptyBar = factory().createViewModel(viewModelState: state, priceData: nil, period: .week, selectedChartIndex: 0, locale: locale)
        XCTAssertEqual(emptyBar?.summaryViewModel.tokenAmount, "0")
        XCTAssertEqual(emptyBar?.isEmpty, true)

        let year = factory().createViewModel(viewModelState: state, priceData: nil, period: .year, selectedChartIndex: nil, locale: locale)
        XCTAssertEqual(year?.chartData.amounts.count, 12)
        XCTAssertEqual(year?.chartData.amounts.filter(\.filled).map(\.value).reduce(0, +) ?? 0, 4.0, accuracy: 1e-9)

        let all = factory().createViewModel(viewModelState: state, priceData: nil, period: .all, selectedChartIndex: nil, locale: locale)
        let first = Date(timeIntervalSince1970: TimeInterval(data[0].timestamp))
        let last = Date(timeIntervalSince1970: TimeInterval(data[1].timestamp))
        let months = CovBAnFixtures.calendar.dateComponents([.month], from: first, to: last).month ?? 0
        XCTAssertEqual(all?.chartData.amounts.count, months + 1)

        let month = factory().createViewModel(viewModelState: state, priceData: nil, period: .month, selectedChartIndex: nil, locale: locale)
        XCTAssertEqual(month?.chartData.amounts.count, 30)
        XCTAssertEqual(month?.summaryViewModel.tokenAmount, "2.5")
    }

    func testRelaychainChartAmountsAndEmptyData() {
        XCTAssertEqual(
            factory().calculateChartAmounts(chartDoubles: [0, 5]),
            [ChartAmount(value: 0.1, selected: false, filled: false), ChartAmount(value: 5, selected: false, filled: true)]
        )
        let state = AnalyticsRewardsRelaychainViewModelState()
        state.didReceieveSubqueryData([])
        let viewModel = factory().createViewModel(viewModelState: state, priceData: nil, period: .week, selectedChartIndex: nil, locale: locale)
        XCTAssertEqual(viewModel?.isEmpty, true)
        XCTAssertEqual(viewModel?.chartData.amounts, [])
    }
}

final class CovBAnStakeViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    private func factory() -> AnalyticsStakeViewModelFactory {
        AnalyticsStakeViewModelFactory(
            assetInfo: CovBAnFixtures.asset().displayInfo,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            calendar: CovBAnFixtures.calendar
        )
    }

    private func changes() throws -> [SubqueryStakeChangeData] {
        [
            try CovBAnFixtures.stakeChange("bond", daysAgo: 3, amount: 100, accumulated: 100, type: "bonded"),
            try CovBAnFixtures.stakeChange("unbond", daysAgo: 2, amount: 30, accumulated: 70, type: "unbonded"),
            try CovBAnFixtures.stakeChange("reward", daysAgo: 1, amount: 5, accumulated: 75, type: "rewarded")
        ]
    }

    func testStakeHistoryChartsAccumulatedStakePerChange() throws {
        let viewModel = factory().createViewModel(
            from: try changes(),
            priceData: CovBAnFixtures.priceData("7"),
            period: .week,
            selectedChartIndex: nil,
            hasPendingRewards: true
        ).value(for: locale)

        let values = viewModel.chartData.amounts.map(\.value)
        XCTAssertEqual(values.count, 3)
        zip(values, [1.0, 0.7, 0.75]).forEach { XCTAssertEqual($0, $1, accuracy: 1e-9) }
        XCTAssertTrue(viewModel.chartData.amounts.allSatisfy { $0.filled && !$0.selected })
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "0.75")
        XCTAssertEqual(viewModel.summaryViewModel.usdAmount, "7")
        XCTAssertEqual(viewModel.sections.count, 3)
        let items = viewModel.sections.flatMap(\.items)
        XCTAssertEqual(items.map(\.rawModel.eventId), ["reward", "unbond", "bond"])
        XCTAssertEqual(items.map(\.viewModel.tokenAmountText), ["+0.05", "-0.3", "+1"])
        XCTAssertEqual(items.map(\.viewModel.addressOrName), [
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages),
            R.string.localizable.stakingUnbond_v190(preferredLanguages: locale.rLanguages),
            R.string.localizable.stakingBondMore_v190(preferredLanguages: locale.rLanguages)
        ])
        XCTAssertEqual(
            viewModel.emptyListDescription,
            R.string.localizable.stakingAnalyticsStakeEmptyMessage(preferredLanguages: locale.rLanguages)
        )
    }

    func testSelectedStakeChangeShowsItsDateAndAccumulatedAmount() throws {
        let data = try changes()
        let viewModel = factory().createViewModel(
            from: data,
            priceData: nil,
            period: .month,
            selectedChartIndex: 1,
            hasPendingRewards: true
        ).value(for: locale)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.locale = locale
        XCTAssertEqual(viewModel.summaryViewModel.title, formatter.string(from: data[1].date))
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "0.7")
        XCTAssertEqual(viewModel.sections.flatMap(\.items).map(\.rawModel.eventId), ["unbond"])
        XCTAssertEqual(viewModel.chartData.amounts.map(\.selected), [false, true, false])
    }

    func testOldStakeChangesKeepTheLastKnownStake() throws {
        let data = [
            try CovBAnFixtures.stakeChange("old-bond", daysAgo: 400, amount: 100, accumulated: 100, type: "bonded"),
            try CovBAnFixtures.stakeChange("old-slash", daysAgo: 390, amount: 10, accumulated: 90, type: "slashed")
        ]
        let viewModel = factory().createViewModel(
            from: data,
            priceData: nil,
            period: .year,
            selectedChartIndex: nil,
            hasPendingRewards: true
        ).value(for: locale)

        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "0.9")
        let items = viewModel.sections.flatMap(\.items)
        XCTAssertEqual(items.map(\.rawModel.eventId), ["old-slash"])
        XCTAssertEqual(items.first?.viewModel.tokenAmountText, "-0.1")
        XCTAssertEqual(items.first?.viewModel.addressOrName, R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages))
    }

    func testStakeChangeConformsToAnalyticsModels() throws {
        let slash = try CovBAnFixtures.stakeChange("s", daysAgo: 1, amount: 3, accumulated: 9, type: "slashed")
        XCTAssertEqual(slash.amountInChart, 9)
        XCTAssertEqual(slash.amountInHistory, 3)
        XCTAssertEqual(slash.amountSign, .minus)
        XCTAssertEqual(slash.typeText(locale: locale), R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages))
        let bonded = try CovBAnFixtures.stakeChange("b", daysAgo: 1, amount: 3, accumulated: 9, type: "bonded")
        XCTAssertEqual(bonded.amountSign, .plus)
        XCTAssertEqual(bonded.date, Date(timeIntervalSince1970: TimeInterval(bonded.timestamp)))
        XCTAssertEqual(factory().calculateChartAmounts(chartDoubles: [0, 2]), [
            ChartAmount(value: 0, selected: false, filled: true),
            ChartAmount(value: 2, selected: false, filled: true)
        ])
    }

    func testNoStakeChangesGiveAnEmptyViewModel() {
        let viewModel = factory().createViewModel(
            from: [],
            priceData: nil,
            period: .all,
            selectedChartIndex: nil,
            hasPendingRewards: true
        ).value(for: locale)
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertEqual(viewModel.summaryViewModel.tokenAmount, "0")
        XCTAssertEqual(viewModel.selectedPeriod, .all)
    }
}

final class CovBAnPeriodAndDetailsTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    func testPeriodTitlesBarCountsAndAxisLabels() {
        XCTAssertEqual(AnalyticsPeriod.default, .week)
        XCTAssertEqual(AnalyticsPeriod.allCases, [.week, .month, .year, .all])
        XCTAssertEqual(
            AnalyticsPeriod.allCases.map { $0.title(for: locale) },
            [
                R.string.localizable.stakingAnalyticsPeriod7d(preferredLanguages: locale.rLanguages).uppercased(),
                R.string.localizable.stakingAnalyticsPeriod30d(preferredLanguages: locale.rLanguages).uppercased(),
                R.string.localizable.stakingAnalyticsPeriod1y(preferredLanguages: locale.rLanguages).uppercased(),
                R.string.localizable.stakingAnalyticsPeriodAll(preferredLanguages: locale.rLanguages).uppercased()
            ]
        )
        let calendar = CovBAnFixtures.calendar
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = calendar.date(byAdding: .month, value: 5, to: start) ?? start
        XCTAssertEqual(AnalyticsPeriod.week.chartBarsCount(startDate: start, endDate: end, calendar: calendar), 7)
        XCTAssertEqual(AnalyticsPeriod.month.chartBarsCount(startDate: start, endDate: end, calendar: calendar), 30)
        XCTAssertEqual(AnalyticsPeriod.year.chartBarsCount(startDate: start, endDate: end, calendar: calendar), 12)
        XCTAssertEqual(AnalyticsPeriod.all.chartBarsCount(startDate: start, endDate: end, calendar: calendar), 6)

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "MMM dd"
        let middle = Date(timeIntervalSince1970: (start.timeIntervalSince1970 + end.timeIntervalSince1970) / 2)
        XCTAssertEqual(
            AnalyticsPeriod.week.xAxisValues(dateRange: (start, end), locale: locale),
            [formatter.string(from: start), formatter.string(from: middle), formatter.string(from: end)]
        )
        formatter.dateFormat = "MMM yyyy"
        XCTAssertEqual(
            AnalyticsPeriod.all.xAxisValues(dateRange: (start, end), locale: locale),
            [formatter.string(from: start), formatter.string(from: middle), formatter.string(from: end)]
        )
    }

    func testDateRangesEndTodayOrAtTheEndOfThisMonth() {
        let calendar = CovBAnFixtures.calendar
        let now = Date()
        let origin = Date(timeIntervalSince1970: 1_600_000_000)

        let week = AnalyticsPeriod.week.dateRangeTillNow(startDate: origin, endDate: now, calendar: calendar)
        XCTAssertTrue(calendar.isDate(week.1, inSameDayAs: now))
        XCTAssertEqual(calendar.component(.hour, from: week.1), 23)
        XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: week.0), to: calendar.startOfDay(for: week.1)).day, 6)

        let month = AnalyticsPeriod.month.dateRangeTillNow(startDate: origin, endDate: now, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: month.0), to: calendar.startOfDay(for: month.1)).day, 29)

        let year = AnalyticsPeriod.year.dateRangeTillNow(startDate: origin, endDate: now, calendar: calendar)
        XCTAssertTrue(calendar.isDate(year.1, equalTo: now, toGranularity: .month))
        XCTAssertLessThan(year.0, year.1)

        let all = AnalyticsPeriod.all.dateRangeTillNow(startDate: origin, endDate: now, calendar: calendar)
        XCTAssertEqual(all.0, origin)
        XCTAssertEqual(all.1, year.1)
    }

    func testValidatorsPageTitles() {
        XCTAssertEqual(AnalyticsValidatorsPage.allCases, [.activity, .rewards])
        XCTAssertEqual(
            AnalyticsValidatorsPage.activity.title(for: locale),
            R.string.localizable.stakingAnalyticsActivity(preferredLanguages: locale.rLanguages).uppercased()
        )
        XCTAssertEqual(
            AnalyticsValidatorsPage.rewards.title(for: locale),
            R.string.localizable.stakingRewardsTitle(preferredLanguages: locale.rLanguages).uppercased()
        )
    }

    func testRewardDetailsViewModelFormatsDateTypeAndAmount() {
        let chainAsset = CovBAnFixtures.chainAsset(precision: 2)
        let factory = AnalyticsRewardDetailsViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: StubBalanceViewModelFactory()
        )
        let reward = CovBAnFixtures.reward("777-1", daysAgo: 2, amount: 150)

        let viewModel = factory.createViweModel(rewardModel: reward).value(for: locale)

        XCTAssertEqual(viewModel.eventId, "777-1")
        XCTAssertEqual(viewModel.date, DateFormatter.txDetails.value(for: locale).string(from: reward.date))
        XCTAssertEqual(viewModel.type, R.string.localizable.stakingRewardDetailsReward(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(viewModel.amount, "1.5")
    }

    func testValidatorItemEqualityIgnoresIcon() {
        let item = AnalyticsValidatorItemViewModel(
            icon: nil,
            validatorName: "Alice",
            amount: 1,
            progressPercents: 0.5,
            mainValueText: "50%",
            secondaryValueText: "1 era",
            progressFullDescription: "50% (1 era)",
            validatorAddress: "address"
        )
        let same = AnalyticsValidatorItemViewModel(
            icon: try? UniversalIconGenerator().generateFromAddress("5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"),
            validatorName: "Alice",
            amount: 1,
            progressPercents: 0.5,
            mainValueText: "50%",
            secondaryValueText: "1 era",
            progressFullDescription: "50% (1 era)",
            validatorAddress: "address"
        )
        let other = AnalyticsValidatorItemViewModel(
            icon: nil,
            validatorName: "Bob",
            amount: 1,
            progressPercents: 0.5,
            mainValueText: "50%",
            secondaryValueText: "1 era",
            progressFullDescription: "50% (1 era)",
            validatorAddress: "address"
        )
        XCTAssertEqual(item, same)
        XCTAssertNotEqual(item, other)
    }
}
