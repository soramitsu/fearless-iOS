import XCTest
@testable import fearless
import SSFModels
import RobinHood
import FearlessFoundation
import Cuckoo

class AnalyticsRewardDetailsTests: XCTestCase {
    func testModule() {
        let viewModelFactory = MockAnalyticsRewardDetailsViewModelFactoryProtocol()
        let wireframe = MockAnalyticsRewardDetailsWireframeProtocol()
        let rewardModel = SubqueryRewardItemData(
            eventId: "111111-2",
            timestamp: 0,
            validatorAddress: "",
            era: 0,
            stashAddress: "",
            amount: 0,
            isReward: true
        )

        let asset = ChainModelGenerator.generateAssetWithId("887a17c7-1370-4de0-97dd-5422e294fa75", symbol: "dot")
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let presenter = AnalyticsRewardDetailsPresenter(
            rewardModel: rewardModel,
            interactor: MockAnalyticsRewardDetailsInteractorInputProtocol(),
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset
        )

        let createViewModelExpectation = XCTestExpectation()
        stub(viewModelFactory) { stub in
            when(stub.createViweModel(rewardModel: any())).then { _ in
                createViewModelExpectation.fulfill()
                return LocalizableResource { _ in
                    .init(eventId: "", date: "", type: "", amount: "")
                }
            }
        }

        let bindViewModelExpectation = XCTestExpectation()
        let view = MockAnalyticsRewardDetailsViewProtocol()

        stub(view) { stub in
            when(stub.bind(viewModel: any())).then { _ in
                bindViewModelExpectation.fulfill()
            }
            when(stub.localizationManager.get).thenReturn(LocalizationManager.shared)
        }
        presenter.view = view

        // Test module setup
        presenter.setup()

        wait(
            for: [createViewModelExpectation, bindViewModelExpectation],
            timeout: Constants.defaultExpectationDuration,
            enforceOrder: true
        )

        // Test 'block number' action
        let presentActionSheetExpectation = XCTestExpectation()
        stub(wireframe) { stub in
            when(stub.present(viewModel: any(), from: any())).then { _ in
                presentActionSheetExpectation.fulfill()
            }
        }
        presenter.handleEventIdAction()

        wait(
            for: [presentActionSheetExpectation],
            timeout: Constants.defaultExpectationDuration
        )
    }
}

final class AnalyticsPeriodTests: XCTestCase {
    func testChartBarsCount_whenPeriodUsesFixedAndAllRanges_thenReturnsExpectedCounts() {
        let calendar = utcCalendar()
        let startDate = makeDate(year: 2024, month: 1, day: 15, calendar: calendar)
        let endDate = makeDate(year: 2024, month: 6, day: 15, calendar: calendar)

        XCTAssertEqual(AnalyticsPeriod.week.chartBarsCount(startDate: startDate, endDate: endDate, calendar: calendar), 7)
        XCTAssertEqual(AnalyticsPeriod.month.chartBarsCount(startDate: startDate, endDate: endDate, calendar: calendar), 30)
        XCTAssertEqual(AnalyticsPeriod.year.chartBarsCount(startDate: startDate, endDate: endDate, calendar: calendar), 12)
        XCTAssertEqual(AnalyticsPeriod.all.chartBarsCount(startDate: startDate, endDate: endDate, calendar: calendar), 6)
    }

    func testXAxisValues_whenPeriodChangesGranularity_thenFormatsBoundaryLabels() {
        let locale = Locale(identifier: "en_US_POSIX")
        let calendar = utcCalendar()
        let startDate = makeDate(year: 2024, month: 1, day: 1, calendar: calendar)
        let endDate = makeDate(year: 2024, month: 7, day: 1, calendar: calendar)

        let weekValues = AnalyticsPeriod.week.xAxisValues(dateRange: (startDate, endDate), locale: locale)
        XCTAssertEqual(weekValues.first, "Jan 01")
        XCTAssertEqual(weekValues.last, "Jul 01")
        XCTAssertEqual(weekValues.count, 3)

        let monthValues = AnalyticsPeriod.month.xAxisValues(dateRange: (startDate, endDate), locale: locale)
        XCTAssertEqual(monthValues.first, "Jan 01")
        XCTAssertEqual(monthValues.last, "Jul 01")
        XCTAssertEqual(monthValues.count, 3)

        let yearValues = AnalyticsPeriod.year.xAxisValues(dateRange: (startDate, endDate), locale: locale)
        XCTAssertEqual(yearValues.first, "Jan 2024")
        XCTAssertEqual(yearValues.last, "Jul 2024")
        XCTAssertEqual(yearValues.count, 3)

        let allValues = AnalyticsPeriod.all.xAxisValues(dateRange: (startDate, endDate), locale: locale)
        XCTAssertEqual(allValues.first, "Jan 2024")
        XCTAssertEqual(allValues.last, "Jul 2024")
        XCTAssertEqual(allValues.count, 3)
    }

    func testDateRangeTillNow_whenPeriodChangesWindow_thenReturnsExpectedBoundaries() {
        let calendar = utcCalendar()
        let historicalStart = makeDate(year: 2021, month: 3, day: 10, calendar: calendar)

        let weekRange = AnalyticsPeriod.week.dateRangeTillNow(
            startDate: historicalStart,
            endDate: .distantFuture,
            calendar: calendar
        )
        let expectedWeekInterval = TimeInterval(604_740)
        XCTAssertEqual(weekRange.1.timeIntervalSince(weekRange.0), expectedWeekInterval)

        let monthRange = AnalyticsPeriod.month.dateRangeTillNow(
            startDate: historicalStart,
            endDate: .distantFuture,
            calendar: calendar
        )
        let expectedMonthInterval = TimeInterval(2_591_940)
        XCTAssertEqual(monthRange.1.timeIntervalSince(monthRange.0), expectedMonthInterval)

        let allRange = AnalyticsPeriod.all.dateRangeTillNow(
            startDate: historicalStart,
            endDate: .distantFuture,
            calendar: calendar
        )
        XCTAssertEqual(allRange.0, historicalStart)
        XCTAssertEqual(calendar.component(.day, from: allRange.1), calendar.range(of: .day, in: .month, for: allRange.1)?.count)
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
