import XCTest
import SoraFoundation
import SoraUI
@testable import fearless

final class CovCBPRPVPresenterDouble: StakingRewardPayoutsPresenterProtocol {
    var setupCount = 0
    var payoutCount = 0
    var reloadCount = 0
    var selected: [Int] = []
    var timeLeftRequests: [Int] = []

    func setup() { setupCount += 1 }
    func handleSelectedHistory(at index: Int) { selected.append(index) }
    func handlePayoutAction() { payoutCount += 1 }
    func reload() { reloadCount += 1 }

    func getTimeLeftString(at index: Int) -> LocalizableResource<NSAttributedString>? {
        timeLeftRequests.append(index)
        return index == 0 ? LocalizableResource { _ in NSAttributedString(string: "updated \(index)") } : nil
    }
}

final class CovCBPRPVTimerDouble: CountdownTimerProtocol {
    weak var delegate: CountdownTimerDelegate?
    var state: CountdownTimerState = .stopped
    var notificationInterval: TimeInterval { 1 }
    var remainedInterval: TimeInterval { 0 }
    var startedIntervals: [TimeInterval] = []
    var stopCount = 0

    func start(with interval: TimeInterval, runLoop _: RunLoop, mode _: RunLoop.Mode) {
        startedIntervals.append(interval)
    }

    func stop() { stopCount += 1 }
}

final class CovCBPRewardPayoutsViewTests: XCTestCase {
    private let languages = ["en"]

    private func makeController(
        timer: CovCBPRPVTimerDouble = CovCBPRPVTimerDouble()
    ) throws -> (StakingRewardPayoutsViewController, CovCBPRPVPresenterDouble) {
        let presenter = CovCBPRPVPresenterDouble()
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = StakingRewardPayoutsViewController(
            presenter: presenter,
            localizationManager: manager,
            countdownTimer: timer
        )
        return (controller, presenter)
    }

    private func makeCell(name: String, token: String, usd: String?) -> StakingRewardHistoryCellViewModel {
        StakingRewardHistoryCellViewModel(
            addressOrName: name,
            daysLeftText: NSAttributedString(string: "3 days left"),
            tokenAmountText: token,
            usdAmountText: usd,
            timeInterval: nil,
            locale: Locale(identifier: "en")
        )
    }

    private func makeList(completion: TimeInterval?) -> StakingRewardPayoutsViewState {
        let cells = [makeCell(name: "Alice", token: "+1 DOT", usd: "$5"), makeCell(name: "Bob", token: "+2 DOT", usd: nil)]
        return .payoutsList(LocalizableResource { _ in
            StakingPayoutViewModel(cellViewModels: cells, eraComletionTime: completion, bottomButtonTitle: "Payout all (3 DOT)")
        })
    }

    private func labelTexts(in cell: UITableViewCell) -> [String] {
        cell.contentView.subviews.compactMap { ($0 as? UILabel)?.text ?? ($0 as? UILabel)?.attributedText?.string }
    }

    func testHistoryCellBindsLabels() {
        let cell = StakingRewardHistoryTableCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 60)
        cell.layoutIfNeeded()

        cell.bind(model: makeCell(name: "Validator", token: "+4 DOT", usd: "$20"))
        let texts = labelTexts(in: cell)
        XCTAssertTrue(texts.contains("Validator"))
        XCTAssertTrue(texts.contains("+4 DOT"))
        XCTAssertTrue(texts.contains("$20"))
        XCTAssertTrue(texts.contains("3 days left"))

        cell.bind(timeLeftText: NSAttributedString(string: "1 day left"))
        XCTAssertTrue(labelTexts(in: cell).contains("1 day left"))
        XCTAssertNotNil(cell.selectedBackgroundView)
    }

    func testLayoutAppliesBottomInset() {
        let layout = StakingRewardPayoutsViewLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.setNeedsLayout()
        layout.layoutIfNeeded()

        XCTAssertGreaterThan(layout.tableView.contentInset.bottom, UIConstants.horizontalInset)
        XCTAssertEqual(layout.tableView.separatorStyle, .none)
    }

    func testLoadSetsUpTitleAndHiddenButton() throws {
        let (controller, presenter) = try makeController()
        controller.loadViewIfNeeded()

        XCTAssertEqual(presenter.setupCount, 1)
        XCTAssertEqual(controller.title, R.string.localizable.stakingRewardPayoutsTitle(preferredLanguages: languages))
        XCTAssertTrue(controller.rootView.payoutButton.isHidden)
        XCTAssertEqual(controller.selectedLocale.identifier, "en")

        let table = controller.rootView.tableView
        XCTAssertEqual(controller.numberOfSections(in: table), 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        let titleCell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? MultilineTableViewCell)
        XCTAssertEqual(
            titleCell.titleLabel.text,
            R.string.localizable.stakingPendingRewardsExplanationMessage(preferredLanguages: languages)
        )
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertNil(controller.viewForEmptyState)
    }

    func testPayoutsListStateConfiguresTableAndTimer() throws {
        let timer = CovCBPRPVTimerDouble()
        let (controller, presenter) = try makeController(timer: timer)
        controller.loadViewIfNeeded()
        let table = controller.rootView.tableView

        controller.reload(with: makeList(completion: 1000))

        XCTAssertFalse(controller.rootView.payoutButton.isHidden)
        XCTAssertEqual(controller.rootView.payoutButton.imageWithTitleView?.title, "Payout all (3 DOT)")
        XCTAssertEqual(timer.startedIntervals, [1000])
        XCTAssertEqual(timer.stopCount, 1)
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 1), 2)

        let header = controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(header is MultilineTableViewCell)

        let row = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 1)) as? StakingRewardHistoryTableCell)
        XCTAssertTrue(labelTexts(in: row).contains("Bob"))
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertNil(controller.viewForEmptyState)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 1))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(presenter.selected, [1])

        controller.rootView.payoutButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.payoutCount, 1)

        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.payoutButton.imageWithTitleView?.title, "Payout all (3 DOT)")

        controller.reload(with: makeList(completion: nil))
        XCTAssertEqual(timer.startedIntervals, [1000])
    }

    func testEmptyAndErrorStates() throws {
        let (controller, presenter) = try makeController()
        controller.loadViewIfNeeded()

        controller.reload(with: .emptyList)
        XCTAssertTrue(controller.rootView.payoutButton.isHidden)
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        let empty = try XCTUnwrap(controller.viewForEmptyState as? EmptyStateView)
        XCTAssertEqual(empty.title, R.string.localizable.stakingRewardPayoutsEmptyRewards(preferredLanguages: languages))

        controller.reload(with: .error(LocalizableResource { _ in "Failure text" }))
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        let errorView = try XCTUnwrap(controller.viewForEmptyState as? ErrorStateView)
        XCTAssertEqual(errorView.errorDescriptionLabel.text, "Failure text")

        controller.didRetry(errorView: errorView)
        XCTAssertEqual(presenter.reloadCount, 1)

        controller.reload(with: .loading(true))
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertNil(controller.viewForEmptyState)
        controller.reload(with: .loading(false))
        XCTAssertEqual(controller.tableView(controller.rootView.tableView, numberOfRowsInSection: 0), 1)
    }

    func testCountdownUpdatesVisibleCells() throws {
        let (controller, presenter) = try makeController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()

        controller.reload(with: makeList(completion: nil))
        controller.rootView.tableView.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        controller.rootView.tableView.layoutIfNeeded()

        controller.didStart(with: 100)
        controller.didCountdown(remainedInterval: 50)
        controller.didStop(with: 0)

        XCTAssertTrue(presenter.timeLeftRequests.contains(0))
        XCTAssertTrue(presenter.timeLeftRequests.contains(1))

        let firstRow = try XCTUnwrap(controller.rootView.tableView.cellForRow(at: IndexPath(row: 0, section: 1)))
        XCTAssertTrue(labelTexts(in: firstRow).contains("updated 0"))

        window.isHidden = true
    }

    func testDeinitStopsTimer() {
        let timer = CovCBPRPVTimerDouble()
        autoreleasepool {
            let controller = StakingRewardPayoutsViewController(
                presenter: CovCBPRPVPresenterDouble(),
                localizationManager: LocalizationManager(localization: "en"),
                countdownTimer: timer
            )
            XCTAssertTrue(timer.delegate === controller)
        }

        XCTAssertEqual(timer.stopCount, 1)
        XCTAssertNil(timer.delegate)
    }
}
