import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJFinStatsFetcher: AccountStatisticsFetching {
    var responses: [AccountStatisticsResponse] = []
    var subscribeError: Error?
    var streamError: Error?
    private let lock = NSLock()
    private var recordedAddresses: [String] = []

    var addresses: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedAddresses
    }

    private func record(_ address: String) {
        lock.lock()
        recordedAddresses.append(address)
        lock.unlock()
    }

    func subscribeForStatistics(address: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        record(address)
        if let subscribeError { throw subscribeError }
        let responses = responses
        let streamError = streamError
        return AsyncThrowingStream { continuation in
            responses.forEach { continuation.yield($0) }
            continuation.finish(throwing: streamError)
        }
    }

    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse? {
        record(address)
        return responses.first
    }
}

final class CovJFinStatsInteractorOutput: AccountStatisticsInteractorOutput {
    private let lock = NSLock()
    private var recordedScores: [Decimal?] = []
    private var recordedErrors: [Error] = []
    private var noData = 0

    var scores: [Decimal?] { locked { recordedScores } }
    var errors: [Error] { locked { recordedErrors } }
    var noDataStates: Int { locked { noData } }

    private func locked<R>(_ block: () -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }

    func didReceiveAccountStatistics(_ response: AccountStatisticsResponse?) { locked { recordedScores.append(response?.data?.score) } }
    func didReceiveAccountStatisticsError(_ error: Error) { locked { recordedErrors.append(error) } }
    func didReceiveNoDataAvailableState() { locked { noData += 1 } }
}

final class CovJFinStatsInteractor: AccountStatisticsInteractorInput {
    weak var output: AccountStatisticsInteractorOutput?
    var fetches = 0
    func setup(with output: AccountStatisticsInteractorOutput) { self.output = output }
    func fetchAccountStatistics() { fetches += 1 }
}

final class CovJFinStatsRouter: AccountStatisticsRouterInput {
    var dismissals = 0
    var statuses: [String] = []
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated _: Bool) { statuses.append(viewModel.titleText) }
    func dismissStatus(with _: ApplicationStatusAlertEvent?, animated _: Bool) {}
}

final class CovJFinStatsView: UIViewController, AccountStatisticsViewInput {
    var viewModels: [AccountStatisticsViewModel?] = []
    var errors = 0
    func didReceive(viewModel: AccountStatisticsViewModel?) { viewModels.append(viewModel) }
    func didReceiveError() { errors += 1 }
}

final class CovJFinStatsViewOutput: AccountStatisticsViewOutput {
    var loads = 0
    var closes = 0
    var copies = 0
    func didLoad(view _: AccountStatisticsViewInput) { loads += 1 }
    func didTapCloseButton() { closes += 1 }
    func didTapCopyAddress() { copies += 1 }
}

final class CovJFinScorePresenter: AccountScorePresentable {}

enum CovJFinStatsFixture {
    static let statsJSON = """
    {"nativeBalanceUSD":1234.5,"holdTokensBalanceUSD":99,"walletAge":14,"totalTransactions":42,
    "totalRejectedTransactions":3,"averageTransactionTime":1.5,"maxTransactionTime":10.25,"minTransactionTime":0.333,"scoredAt":0}
    """

    static func stats(_ json: String = statsJSON) throws -> AccountStatisticsData {
        try JSONDecoder().decode(AccountStatisticsData.self, from: Data(json.utf8))
    }

    static func statistics(score: String?, address: String? = "5Grw", stats: AccountStatisticsData? = nil) -> AccountStatistics {
        AccountStatistics(score: score.flatMap { Decimal(string: $0) }, address: address, stats: stats)
    }
}

final class CovJFinAccountStatisticsTests: XCTestCase {
    private let locale = CovJFixture.locale

    func testViewModelFactoryFormatsScoreAndStatistics() throws {
        let factory = AccountStatisticsViewModelFactoryImpl()
        XCTAssertNil(factory.buildViewModel(accountScore: nil, locale: locale))
        XCTAssertNil(factory.buildViewModel(accountScore: CovJFinStatsFixture.statistics(score: nil), locale: locale))

        let statistics = CovJFinStatsFixture.statistics(score: "0.84", stats: try CovJFinStatsFixture.stats())
        let viewModel = try XCTUnwrap(factory.buildViewModel(accountScore: statistics, locale: locale))
        let fiat = AssetBalanceFormatterFactory()
            .createTokenFormatter(for: AssetBalanceDisplayInfo.forCurrency(.defaultCurrency()), usageCase: .fiat).value(for: locale)
        XCTAssertEqual(viewModel.rating ?? 0, 4.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.scoreLabelText, "84")
        XCTAssertEqual(viewModel.rate, .high)
        XCTAssertEqual(viewModel.addressViewText, "5Grw")
        XCTAssertEqual(viewModel.updatedLabelText, DateFormatter.shortDate.value(for: locale).string(from: Date(timeIntervalSinceReferenceDate: 0)))
        XCTAssertEqual(viewModel.nativeBalanceUsdLabelText, fiat.stringFromDecimal(Decimal(string: "1234.5") ?? 0))
        XCTAssertEqual(viewModel.holdTokensUsdLabelText, fiat.stringFromDecimal(99))
        XCTAssertEqual(viewModel.walletAgeLabelText, "14 month")
        XCTAssertEqual(viewModel.totalTransactionsLabelText, "42")
        XCTAssertEqual(viewModel.rejectedTransactionsLabelText, "3")
        XCTAssertEqual(viewModel.avgTransactionTimeLabelText, "1.5 hours")
        XCTAssertEqual(viewModel.maxTransactionTimeLabelText, "10.25 hours")
        XCTAssertEqual(viewModel.minTransactionTimeLabelText, "0.33 hours")
    }

    func testViewModelFactoryRatesLowAndMediumScoresWithoutStatistics() throws {
        let factory = AccountStatisticsViewModelFactoryImpl()
        let low = try XCTUnwrap(factory.buildViewModel(accountScore: CovJFinStatsFixture.statistics(score: "0.1", address: nil), locale: locale))
        XCTAssertEqual(low.rate, .low)
        XCTAssertEqual(low.scoreLabelText, "10")
        XCTAssertEqual(low.rating ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertNil(low.addressViewText)
        XCTAssertNil(low.updatedLabelText)
        XCTAssertNil(low.walletAgeLabelText)
        XCTAssertNil(low.avgTransactionTimeLabelText)
        let emptyStats = CovJFinStatsFixture.statistics(score: "0.5", stats: try CovJFinStatsFixture.stats("{}"))
        let medium = try XCTUnwrap(factory.buildViewModel(accountScore: emptyStats, locale: locale))
        XCTAssertEqual(medium.rate, .medium)
        XCTAssertEqual(medium.scoreLabelText, "50")
        XCTAssertNil(medium.nativeBalanceUsdLabelText)
        XCTAssertNil(medium.totalTransactionsLabelText)
        XCTAssertNil(medium.maxTransactionTimeLabelText)
    }

    func testInteractorStreamsStatisticsAndReportsMissingAddressAndFailures() throws {
        let fetcher = CovJFinStatsFetcher()
        fetcher.responses = [
            AccountStatisticsResponse(data: CovJFinStatsFixture.statistics(score: "0.2")),
            AccountStatisticsResponse(data: nil)
        ]
        let output = CovJFinStatsInteractorOutput()
        let interactor = AccountStatisticsInteractor(accountScoreFetcher: fetcher, address: "5Grw")
        interactor.setup(with: output)
        interactor.fetchAccountStatistics()
        XCTAssertTrue(CovJWait.until { output.scores.count == 2 })
        XCTAssertEqual(output.scores, [Decimal(string: "0.2"), nil])
        XCTAssertEqual(fetcher.addresses, ["5Grw"])
        XCTAssertTrue(output.errors.isEmpty)

        fetcher.streamError = CovJError("stream broke")
        interactor.fetchAccountStatistics()
        XCTAssertTrue(CovJWait.until { output.errors.count == 1 })
        XCTAssertEqual(output.errors.first as? CovJError, CovJError("stream broke"))

        fetcher.subscribeError = CovJError("no subscription")
        interactor.fetchAccountStatistics()
        XCTAssertTrue(CovJWait.until { output.errors.count == 2 })
        XCTAssertEqual(output.errors.last as? CovJError, CovJError("no subscription"))

        let anonymous = AccountStatisticsInteractor(accountScoreFetcher: fetcher, address: nil)
        anonymous.setup(with: output)
        anonymous.fetchAccountStatistics()
        XCTAssertEqual(output.noDataStates, 1)
        XCTAssertEqual(fetcher.addresses.count, 3)
    }

    func testPresenterLoadsBuildsViewModelsAndRoutes() throws {
        let interactor = CovJFinStatsInteractor()
        let router = CovJFinStatsRouter()
        let presenter = AccountStatisticsPresenter(
            interactor: interactor, router: router, localizationManager: LocalizationManager.shared,
            viewModelFactory: AccountStatisticsViewModelFactoryImpl(), logger: Logger.shared
        )
        let view = CovJFinStatsView()
        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(interactor.fetches, 1)
        XCTAssertTrue(CovJWait.until { view.viewModels.count == 1 })
        XCTAssertNil(view.viewModels.first ?? nil)

        presenter.didReceiveAccountStatistics(AccountStatisticsResponse(data: CovJFinStatsFixture.statistics(score: "0.9")))
        XCTAssertTrue(CovJWait.until { view.viewModels.count == 2 })
        XCTAssertEqual(view.viewModels.last??.scoreLabelText, "90")
        XCTAssertEqual(view.viewModels.last??.rate, .high)
        presenter.didReceiveAccountStatistics(nil)
        XCTAssertTrue(CovJWait.until { view.viewModels.count == 3 })
        XCTAssertNil(view.viewModels.last ?? nil)

        presenter.didReceiveAccountStatisticsError(CovJError("nomis"))
        presenter.didReceiveNoDataAvailableState()
        XCTAssertEqual(view.errors, 1)
        presenter.didTapCloseButton()
        XCTAssertEqual(router.dismissals, 1)
        presenter.didTapCopyAddress()
        XCTAssertEqual(router.statuses, [AddressCopiedEvent(locale: LocalizationManager.shared.selectedLocale).titleText])
        presenter.applyLocalization()
        CovJWait.drain()
        XCTAssertEqual(view.viewModels.count, 3)
    }

    func testControllerBindsStatisticsShowsEmptyStateAndForwardsActions() throws {
        let output = CovJFinStatsViewOutput()
        let controller = AccountStatisticsViewController(output: output, localizationManager: LocalizationManager.shared, address: "5Grw")
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = try XCTUnwrap(controller.view as? AccountStatisticsViewLayout)
        XCTAssertEqual(output.loads, 1)

        let factory = AccountStatisticsViewModelFactoryImpl()
        let statistics = CovJFinStatsFixture.statistics(score: "0.6", stats: try CovJFinStatsFixture.stats())
        controller.didReceive(viewModel: factory.buildViewModel(accountScore: statistics, locale: locale))
        XCTAssertEqual(root.scoreLabel.text, "60")
        XCTAssertEqual(root.walletAgeView.valueLabel.text, "14 month")
        XCTAssertFalse(controller.shouldDisplayEmptyState)

        controller.didReceiveError()
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        XCTAssertTrue(root.stackView.isHidden)
        XCTAssertTrue(controller.contentViewForEmptyState === root.contentBackgroundView)
        XCTAssertFalse(CovJViewFixture.descendants(EmptyView.self, in: root.contentBackgroundView).isEmpty)
        let empty = try XCTUnwrap(controller.viewForEmptyState as? EmptyView)
        let selected = controller.selectedLocale
        XCTAssertEqual(empty.title, R.string.localizable.emptyViewTitle(preferredLanguages: selected.rLanguages))
        XCTAssertEqual(empty.text, R.string.localizable.accountStatsErrorMessage(preferredLanguages: selected.rLanguages))
        XCTAssertTrue(controller.emptyStateDelegate === controller)

        root.closeButton.sendActions(for: .touchUpInside)
        root.topBar.backButton.sendActions(for: .touchUpInside)
        root.addressView.onСopied?()
        XCTAssertEqual(output.closes, 2)
        XCTAssertEqual(output.copies, 1)
        controller.applyLocalization()
        XCTAssertEqual(root.locale, selected)
    }

    func testAssemblyWithoutAddressShowsNoDataAndPresentableShowsIt() throws {
        let module = try XCTUnwrap(AccountStatisticsAssembly.configureModule(address: nil))
        let controller = try XCTUnwrap(module.view.controller as? AccountStatisticsViewController)
        XCTAssertTrue(module.input is AccountStatisticsPresenter)
        XCTAssertTrue(CovJWait.until { controller.shouldDisplayEmptyState })

        let host = try CovJHostedView()
        defer { host.close() }
        CovJFinScorePresenter().presentAccountScore(address: nil, from: nil)
        XCTAssertNil(host.presented)
        CovJFinScorePresenter().presentAccountScore(address: nil, from: host)
        XCTAssertTrue(CovJWait.until { host.presented is AccountStatisticsViewController })
        let presented = try XCTUnwrap(host.presented as? AccountStatisticsViewController)
        XCTAssertTrue(CovJWait.until { presented.shouldDisplayEmptyState })
        XCTAssertTrue(CovJWait.until(timeout: 3) { !presented.isBeingPresented && presented.view.window != nil })
        AccountStatisticsRouter().dismiss(view: presented)
        XCTAssertTrue(CovJWait.until(timeout: 3) { host.presented == nil })
    }
}
