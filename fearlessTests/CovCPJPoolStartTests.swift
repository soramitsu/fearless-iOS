import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJStartOutputDouble: StakingPoolStartViewOutput {
    private(set) var loadedView: StakingPoolStartViewInput?
    private(set) var actions: [String] = []

    func didLoad(view: StakingPoolStartViewInput) { loadedView = view }
    func didTapBackButton() { actions.append("back") }
    func didTapJoinPoolButton() { actions.append("join") }
    func didTapCreatePoolButton() { actions.append("create") }
    func didTapWatchAboutButton() { actions.append("watch") }
}

final class CovCPJStartViewDouble: StakingPoolStartViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }

    private(set) var locales: [Locale] = []
    private(set) var viewModels: [StakingPoolStartViewModel] = []

    func didReceive(locale: Locale) { locales.append(locale) }
    func didReceive(viewModel: StakingPoolStartViewModel) { viewModels.append(viewModel) }
}

final class CovCPJStartInteractorDouble: StakingPoolStartInteractorInput {
    private(set) weak var output: StakingPoolStartInteractorOutput?

    func setup(with output: StakingPoolStartInteractorOutput) { self.output = output }
}

final class CovCPJStartRouterDouble: CovCPJPresentableRecorder, StakingPoolStartRouterInput {
    private(set) var joinAmounts: [Decimal?] = []
    private(set) var createAmounts: [Decimal?] = []
    private(set) var walletIds: [String] = []

    func presentJoinFlow(
        chainAsset _: ChainAsset,
        wallet: fearless.MetaAccountModel,
        amount: Decimal?,
        from _: ControllerBackedProtocol?
    ) {
        joinAmounts.append(amount)
        walletIds.append(wallet.metaId)
    }

    func presentCreateFlow(
        chainAsset _: ChainAsset,
        wallet: fearless.MetaAccountModel,
        amount: Decimal?,
        from _: ControllerBackedProtocol?
    ) {
        createAmounts.append(amount)
        walletIds.append(wallet.metaId)
    }
}

final class CovCPJStartCalculatorStub: RewardCalculatorEngineProtocol {
    let returnValue: Decimal
    var rewardAssetRate: Decimal { 1 }

    init(returnValue: Decimal) {
        self.returnValue = returnValue
    }

    func calculateEarnings(amount: Decimal, validatorAccountId _: AccountId, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal {
        amount * returnValue
    }

    func calculateMaxEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal {
        amount * returnValue
    }

    func calculateAvgEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal {
        amount * returnValue
    }

    func calculatorReturn(isCompound _: Bool, period _: CalculationPeriod, type _: RewardReturnType) -> Decimal {
        returnValue
    }

    func maxEarningsTitle(locale _: Locale) -> String { "max" }
    func avgEarningTitle(locale _: Locale) -> String { "avg" }
}

final class CovCPJPoolStartViewTests: XCTestCase {
    private let languages = CovCPJFixtures.languages
    private let day: TimeInterval = 86400

    private func makeLayout() -> StakingPoolStartViewLayout {
        let view = StakingPoolStartViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = CovCPJFixtures.locale
        view.layoutIfNeeded()
        return view
    }

    private func fullViewModel(chainAsset: ChainAsset, apr: Decimal?) -> StakingPoolStartViewModel {
        StakingPoolStartViewModelFactory(chainAsset: chainAsset).buildViewModel(
            rewardsDelay: day,
            apr: apr,
            unstakePeriod: day * 28,
            rewardsFreq: day,
            locale: CovCPJFixtures.locale
        )
    }

    func testLayoutLocalizesButtonsAndTitles() {
        let view = makeLayout()

        XCTAssertEqual(view.joinButton.imageWithTitleView?.title, R.string.localizable.poolStakingJoinTitle(preferredLanguages: languages))
        XCTAssertEqual(
            view.createButton.imageWithTitleView?.title,
            R.string.localizable.stakingPoolStartCreateButtonTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(view.whatIsStakingView.title, R.string.localizable.poolStakingStartAboutTitle(preferredLanguages: languages))
        XCTAssertEqual(
            view.whatIsStakingView.actionButton?.imageWithTitleView?.title,
            R.string.localizable.commonWatch(preferredLanguages: languages)
        )
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.poolStakingTitle(preferredLanguages: languages))
    }

    func testFactoryBuildsAllSections() {
        let chainAsset = CovCPJFixtures.chainAsset(symbol: "dot")
        let viewModel = fullViewModel(chainAsset: chainAsset, apr: Decimal(string: "0.15"))
        let dayText = day.readableValue(locale: CovCPJFixtures.locale)
        let unstakeText = (day * 28).readableValue(locale: CovCPJFixtures.locale)

        XCTAssertEqual(viewModel.aboutText, R.string.localizable.poolStakingStartAboutTitle(preferredLanguages: languages))
        XCTAssertEqual(
            viewModel.descriptionText?.string,
            R.string.localizable.stakingPoolStartEarnRewardTitle("DOT", preferredLanguages: languages)
        )
        XCTAssertEqual(
            viewModel.delayDetailsViewModel?.title?.string,
            R.string.localizable.stakingPoolRewardsDelayText(dayText, preferredLanguages: languages)
        )
        XCTAssertNotNil(viewModel.delayDetailsViewModel?.icon)
        XCTAssertTrue(viewModel.estimatedRewardViewModel?.title?.string.contains("15") ?? false)
        XCTAssertEqual(
            viewModel.unstakePeriodViewModel?.title?.string,
            R.string.localizable.stakingPoolStartUnstakePeriodText(unstakeText, preferredLanguages: languages)
        )
        XCTAssertEqual(
            viewModel.rewardsFreqViewModel?.title?.string,
            R.string.localizable.stakingPoolStartRewardFreqText(dayText, preferredLanguages: languages)
        )
    }

    func testFactoryWithoutDataLeavesSectionsEmpty() {
        let viewModel = StakingPoolStartViewModelFactory(chainAsset: CovCPJFixtures.chainAsset()).buildViewModel(
            rewardsDelay: nil,
            apr: nil,
            unstakePeriod: nil,
            rewardsFreq: nil,
            locale: CovCPJFixtures.locale
        )

        XCTAssertNil(viewModel.delayDetailsViewModel)
        XCTAssertNil(viewModel.unstakePeriodViewModel)
        XCTAssertNil(viewModel.rewardsFreqViewModel)
        XCTAssertNotNil(viewModel.estimatedRewardViewModel?.icon)
        XCTAssertNil(viewModel.estimatedRewardViewModel?.title)
        XCTAssertNotNil(viewModel.descriptionText)
    }

    func testBindFullViewModel() {
        let view = makeLayout()
        let viewModel = fullViewModel(chainAsset: CovCPJFixtures.chainAsset(), apr: Decimal(string: "0.1"))

        view.bind(viewModel: viewModel)

        XCTAssertEqual(view.earnRewardsLabel.attributedText?.string, viewModel.descriptionText?.string)
        XCTAssertEqual(view.delayView.titleLabel.attributedText?.string, viewModel.delayDetailsViewModel?.title?.string)
        XCTAssertNotNil(view.delayView.iconImage)
        XCTAssertEqual(
            view.estimatedRewardView.titleLabel.attributedText?.string,
            viewModel.estimatedRewardViewModel?.title?.string
        )
        XCTAssertEqual(view.unstakePeriodView.titleLabel.attributedText?.string, viewModel.unstakePeriodViewModel?.title?.string)
        XCTAssertEqual(view.rewardsFreqView.titleLabel.attributedText?.string, viewModel.rewardsFreqViewModel?.title?.string)
    }

    func testBindWithoutAprShowsUpdatingEstimate() {
        let view = makeLayout()
        let viewModel = fullViewModel(chainAsset: CovCPJFixtures.chainAsset(), apr: nil)

        view.bind(viewModel: viewModel)

        XCTAssertEqual(
            view.estimatedRewardView.titleLabel.text,
            R.string.localizable.stakingValidatorEstimatedReward(preferredLanguages: languages)
        )
    }

    func testControllerLoadsAndForwardsActions() throws {
        let output = CovCPJStartOutputDouble()
        let controller = StakingPoolStartViewController(
            output: output,
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        let window = CovCPJFixtures.host(controller)

        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.rootView.whatIsStakingView.actionButton?.sendActions(for: .touchUpInside)
        controller.rootView.joinButton.sendActions(for: .touchUpInside)
        controller.rootView.createButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(output.loadedView === controller)
        XCTAssertEqual(output.actions, ["back", "watch", "join", "create"])
        window.isHidden = true
    }

    func testControllerReceivesLocaleAndViewModel() throws {
        let controller = StakingPoolStartViewController(
            output: CovCPJStartOutputDouble(),
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        controller.loadViewIfNeeded()
        let viewModel = fullViewModel(chainAsset: CovCPJFixtures.chainAsset(), apr: Decimal(string: "0.2"))

        controller.didReceive(locale: CovCPJFixtures.locale)
        controller.didReceive(viewModel: viewModel)

        XCTAssertEqual(controller.title, R.string.localizable.poolStakingTitle(preferredLanguages: languages))
        XCTAssertEqual(controller.rootView.joinButton.imageWithTitleView?.title, R.string.localizable.poolStakingJoinTitle(preferredLanguages: languages))
        XCTAssertEqual(controller.rootView.earnRewardsLabel.attributedText?.string, viewModel.descriptionText?.string)
    }
}

final class CovCPJPoolStartPresenterTests: XCTestCase {
    private var view: CovCPJStartViewDouble!
    private var interactor: CovCPJStartInteractorDouble!
    private var router: CovCPJStartRouterDouble!
    private var logger: CovCPJLoggerDouble!
    private var validationView: CovCPJValidationViewDouble!
    private var wallet: fearless.MetaAccountModel!
    private var presenter: StakingPoolStartPresenter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        view = CovCPJStartViewDouble()
        interactor = CovCPJStartInteractorDouble()
        router = CovCPJStartRouterDouble()
        logger = CovCPJLoggerDouble()
        validationView = CovCPJValidationViewDouble()
        wallet = CovCPJFixtures.wallet()
        let chainAsset = CovCPJFixtures.chainAsset()
        let validatingFactory = StakingDataValidatingFactory(presentable: router)
        validatingFactory.view = validationView

        presenter = StakingPoolStartPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try CovCPJFixtures.localizationManager(),
            viewModelFactory: StakingPoolStartViewModelFactory(chainAsset: chainAsset),
            wallet: wallet,
            chainAsset: chainAsset,
            amount: 3,
            logger: logger,
            dataValidatingFactory: validatingFactory
        )
        presenter.didLoad(view: view)
    }

    override func tearDown() {
        presenter = nil
        view = nil
        interactor = nil
        router = nil
        logger = nil
        validationView = nil
        wallet = nil
        super.tearDown()
    }

    private func networkInfo(existing: UInt32?, maximum: UInt32?) -> StakingPoolNetworkInfo {
        StakingPoolNetworkInfo(
            minJoinBond: nil,
            minCreateBond: nil,
            existingPoolsCount: existing,
            possiblePoolsCount: maximum,
            maxMembersInPool: nil,
            maxPoolsMembers: nil
        )
    }

    func testDidLoadProvidesLocaleAndEmptyViewModel() {
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.locales.count, 1)
        XCTAssertEqual(view.viewModels.count, 1)
        XCTAssertNil(view.viewModels.first?.delayDetailsViewModel)
        XCTAssertNil(view.viewModels.first?.estimatedRewardViewModel?.title)
    }

    func testDurationAndCalculatorFillViewModel() {
        presenter.didReceive(stakingDuration: StakingDuration(session: 3600, era: 86400, unlocking: 86400 * 7))
        XCTAssertNotNil(view.viewModels.last?.delayDetailsViewModel)
        XCTAssertNotNil(view.viewModels.last?.unstakePeriodViewModel)
        XCTAssertNotNil(view.viewModels.last?.rewardsFreqViewModel)

        presenter.didReceive(calculator: CovCPJStartCalculatorStub(returnValue: Decimal(string: "0.25") ?? 0))
        XCTAssertTrue(view.viewModels.last?.estimatedRewardViewModel?.title?.string.contains("25") ?? false)
        XCTAssertEqual(view.viewModels.count, 3)
    }

    func testErrorsAreLogged() {
        presenter.didReceive(error: CovCPJTestError.failed)
        presenter.didReceive(calculatorError: CovCPJTestError.failed)

        XCTAssertEqual(logger.errors.count, 2)
        XCTAssertEqual(view.viewModels.count, 1)
    }

    func testBackAndJoinActions() {
        presenter.didTapBackButton()
        presenter.didTapJoinPoolButton()

        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertEqual(router.joinAmounts, [3])
        XCTAssertEqual(router.walletIds, [wallet.metaId])
    }

    func testCreateIsBlockedWithoutNetworkInfoOrWhenLimitReached() {
        presenter.didTapCreatePoolButton()
        XCTAssertEqual(router.maximumPoolsReachedCount, 1)

        presenter.didReceive(networkInfo: networkInfo(existing: 10, maximum: 10))
        presenter.didTapCreatePoolButton()
        XCTAssertEqual(router.maximumPoolsReachedCount, 2)
        XCTAssertTrue(router.createAmounts.isEmpty)
    }

    func testCreateOpensFlowWhenLimitNotReached() {
        presenter.didReceive(networkInfo: networkInfo(existing: 2, maximum: 10))

        presenter.didTapCreatePoolButton()

        XCTAssertEqual(router.createAmounts, [3])
        XCTAssertEqual(router.maximumPoolsReachedCount, 0)
    }

    func testWatchAboutOpensWikiAndLocalizationResendsLocale() throws {
        presenter.didTapWatchAboutButton()

        let expected = try XCTUnwrap(ApplicationConfig().poolStakingAboutURL)
        XCTAssertEqual(router.shownWebURLs, [expected])

        presenter.applyLocalization()
        XCTAssertEqual(view.locales.count, 2)
    }
}
