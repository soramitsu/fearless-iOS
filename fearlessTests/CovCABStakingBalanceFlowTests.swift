import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCABSBFTimer: CountdownTimerProtocol {
    weak var delegate: CountdownTimerDelegate?
    var state: CountdownTimerState = .stopped
    var notificationInterval: TimeInterval = 1
    var remainedInterval: TimeInterval = 0
    private(set) var startedIntervals: [TimeInterval] = []
    private(set) var stopCalls = 0

    func start(with interval: TimeInterval, runLoop _: RunLoop, mode _: RunLoop.Mode) {
        startedIntervals.append(interval)
    }

    func stop() {
        stopCalls += 1
    }
}

final class CovCABSBFListener: StakingBalanceModelStateListener {
    private(set) var changes = 0
    private(set) var finishCalls = 0
    private(set) var setupRebondCalls = 0
    private(set) var confirmFlows: [StakingRebondConfirmationFlow] = []

    func modelStateDidChanged(viewModelState _: StakingBalanceViewModelState) {
        changes += 1
    }

    func finishFlow() {
        finishCalls += 1
    }

    func decideShowSetupRebondFlow() {
        setupRebondCalls += 1
    }

    func decideShowConfirmRebondFlow(flow: StakingRebondConfirmationFlow) {
        confirmFlows.append(flow)
    }
}

final class CovCABSBFStrategy: StakingBalanceStrategy {
    private(set) var setupCalls = 0

    func setup() {
        setupCalls += 1
    }
}

final class CovCABSBFValidationPresentable: StakingErrorPresentable, SheetAlertPresentable, ErrorPresentable {
    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

enum CovCABSBFError: Error {
    case failed
}

enum CovCABSBFFixtures {
    static func ledger(active: String, unlocking: [(String, String)]) throws -> StakingLedger {
        let chunks = unlocking.map { ["value": $0.0, "era": $0.1] }
        let payload: [String: Any] = [
            "stash": Data(repeating: 1, count: 32).toHex(includePrefix: true),
            "total": "5000000000000",
            "active": active,
            "unlocking": chunks,
            "claimedRewards": []
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        return try JSONDecoder().decode(StakingLedger.self, from: data)
    }

    static func eraCountdown(activeEra: EraIndex = 100) -> EraCountdown {
        EraCountdown(
            activeEra: activeEra,
            currentEra: activeEra,
            eraLength: 6,
            sessionLength: 600,
            activeEraStartSessionIndex: 10,
            currentSessionIndex: 12,
            currentSlot: 12 * 600 + 100,
            genesisSlot: 0,
            blockCreationTime: 6000,
            createdAtDate: Date()
        )
    }

    static func account(chain: ChainModel, name: String) -> fearless.ChainAccountResponse {
        fearless.ChainAccountResponse(
            chainId: chain.chainId,
            accountId: Data(repeating: 7, count: 32),
            publicKey: Data(repeating: 7, count: 32),
            name: name,
            cryptoType: .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: "wallet"
        )
    }
}

final class CovCABStakingBalanceFlowTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private var timer: CovCABSBFTimer!
    private var listener: CovCABSBFListener!
    private var state: StakingBalanceRelaychainViewModelState!

    override func setUp() {
        super.setUp()
        timer = CovCABSBFTimer()
        listener = CovCABSBFListener()
        let validating = StakingDataValidatingFactory(presentable: CovCABSBFValidationPresentable())
        state = StakingBalanceRelaychainViewModelState(countdownTimer: timer, dataValidatingFactory: validating)
        state.setStateListener(listener)
    }

    override func tearDown() {
        state = nil
        listener = nil
        timer = nil
        super.tearDown()
    }

    func testInitAssignsTimerDelegateAndFlows() {
        XCTAssertTrue(timer.delegate === state)
        XCTAssertTrue(state.stateListener === listener)
        XCTAssertEqual(state.bondMoreFlow, .relaychain)
        XCTAssertEqual(state.unbondFlow, .relaychain)
        XCTAssertEqual(state.revokeFlow, .relaychain)
        XCTAssertEqual(state.rebondCases, StakingRebondOption.allCases)
        XCTAssertNil(state.stakingBalanceData)
    }

    func testBalanceDataRequiresLedgerEraAndCountdown() throws {
        let ledger = try CovCABSBFFixtures.ledger(active: "3000000000000", unlocking: [])

        state.didReceive(ledgerResult: .success(ledger))
        state.didReceive(activeEraResult: .success(100))
        XCTAssertNil(state.stakingBalanceData)
        XCTAssertEqual(listener.changes, 2)

        let countdown = CovCABSBFFixtures.eraCountdown()
        state.didReceive(eraCountdownResult: .success(countdown))
        XCTAssertEqual(timer.startedIntervals.count, 1)

        let data = try XCTUnwrap(state.stakingBalanceData)
        XCTAssertEqual(data.activeEra, 100)
        XCTAssertEqual(data.stakingLedger, ledger)
        XCTAssertEqual(data.eraCountdown?.activeEra, 100)

        state.didReceive(ledgerResult: .failure(CovCABSBFError.failed))
        XCTAssertNil(state.stakingLedger)
        XCTAssertNil(state.stakingBalanceData)

        state.didReceive(ledgerResult: .success(ledger))
        state.didReceive(activeEraResult: .failure(CovCABSBFError.failed))
        XCTAssertNil(state.stakingBalanceData)

        state.didReceive(activeEraResult: .success(100))
        state.didReceive(eraCountdownResult: .failure(CovCABSBFError.failed))
        XCTAssertNil(state.stakingBalanceData)
        XCTAssertEqual(listener.changes, 6)
    }

    func testStashControllerAndAccountResults() {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let account = CovCABSBFFixtures.account(chain: chain, name: "acc")

        state.didReceive(stashItemResult: .success(StashItem(stash: "stash", controller: "ctrl")))
        XCTAssertEqual(listener.finishCalls, 0)

        state.didReceive(stashItemResult: .success(nil))
        XCTAssertEqual(listener.finishCalls, 1)

        state.didReceive(stashItemResult: .failure(CovCABSBFError.failed))
        XCTAssertEqual(listener.finishCalls, 1)

        state.didReceive(controllerResult: .success(account))
        XCTAssertEqual(state.controllerAccount, account)
        state.didReceive(controllerResult: .failure(CovCABSBFError.failed))
        XCTAssertNil(state.controllerAccount)

        state.didReceive(stashResult: .success(account))
        XCTAssertEqual(state.stashAccount, account)
        state.didReceive(stashResult: .failure(CovCABSBFError.failed))
        XCTAssertNil(state.stashAccount)
    }

    func testValidatorsReflectAccounts() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let account = CovCABSBFFixtures.account(chain: chain, name: "acc")
        state.didReceive(stashItemResult: .success(StashItem(stash: "stash", controller: "ctrl")))

        XCTAssertEqual(state.stakeMoreValidators(using: locale).count, 1)
        XCTAssertEqual(state.stakeLessValidators(using: locale).count, 2)
        XCTAssertEqual(state.revokeValidators(using: locale).count, 1)
        XCTAssertEqual(state.unbondingMoreValidators(using: locale).count, 1)

        var completions = 0
        DataValidationRunner(validators: state.stakeMoreValidators(using: locale)).runValidation { completions += 1 }
        DataValidationRunner(validators: state.revokeValidators(using: locale)).runValidation { completions += 1 }
        XCTAssertEqual(completions, 0)

        state.stashAccount = account
        state.controllerAccount = account
        state.stakingLedger = try CovCABSBFFixtures.ledger(active: "1", unlocking: [("1", "1")])

        DataValidationRunner(validators: state.stakeMoreValidators(using: locale)).runValidation { completions += 1 }
        DataValidationRunner(validators: state.stakeLessValidators(using: locale)).runValidation { completions += 1 }
        DataValidationRunner(validators: state.revokeValidators(using: locale)).runValidation { completions += 1 }
        DataValidationRunner(validators: state.unbondingMoreValidators(using: locale)).runValidation { completions += 1 }
        XCTAssertEqual(completions, 4)
    }

    func testDecideRebondFlowNotifiesListener() {
        state.decideRebondFlow(option: .all)
        state.decideRebondFlow(option: .last)
        state.decideRebondFlow(option: .customAmount)

        XCTAssertEqual(listener.setupRebondCalls, 1)
        XCTAssertEqual(listener.confirmFlows.count, 2)

        guard case let .relaychain(firstVariant) = listener.confirmFlows[0], case .all = firstVariant else {
            return XCTFail("expected all variant")
        }
        guard case let .relaychain(secondVariant) = listener.confirmFlows[1], case .last = secondVariant else {
            return XCTFail("expected last variant")
        }
    }

    func testCountdownDelegateCallbacksNotifyListener() {
        state.didStart(with: 10)
        state.didCountdown(remainedInterval: 5)
        state.didStop(with: 0)

        XCTAssertEqual(listener.changes, 3)
    }

    func testDeinitStopsTimer() {
        let localTimer = CovCABSBFTimer()
        var localState: StakingBalanceRelaychainViewModelState? = StakingBalanceRelaychainViewModelState(
            countdownTimer: localTimer,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: CovCABSBFValidationPresentable())
        )
        XCTAssertNotNil(localState)
        localState = nil

        XCTAssertEqual(localTimer.stopCalls, 1)
    }

    func testInteractorSetupAndRefreshRunStrategy() {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let strategy = CovCABSBFStrategy()
        let interactor = StakingBalanceInteractor(chainAsset: ChainAsset(chain: chain, asset: asset), strategy: strategy)

        interactor.setup()
        interactor.refresh()

        XCTAssertEqual(strategy.setupCalls, 2)
        XCTAssertEqual(interactor.chainAsset.asset.symbol, "DOT")
    }
}

final class CovCABStakingBalanceViewModelFactoryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let languages = ["en"]
    private var asset: AssetModel!
    private var balanceFactory: BalanceViewModelFactory!
    private var factory: StakingBalanceRelaychainViewModelFactory!
    private var state: StakingBalanceRelaychainViewModelState!

    override func setUp() {
        super.setUp()
        asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 12)
        let wallet = AccountGenerator.generateMetaAccount()
        balanceFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
        factory = StakingBalanceRelaychainViewModelFactory(
            asset: asset,
            balanceViewModelFactory: balanceFactory,
            timeFormatter: TotalTimeFormatter()
        )
        state = StakingBalanceRelaychainViewModelState(
            countdownTimer: CovCABSBFTimer(),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: CovCABSBFValidationPresentable())
        )
    }

    override func tearDown() {
        state = nil
        factory = nil
        balanceFactory = nil
        asset = nil
        super.tearDown()
    }

    private func feed(ledger: StakingLedger) {
        state.didReceive(ledgerResult: .success(ledger))
        state.didReceive(activeEraResult: .success(100))
        state.didReceive(eraCountdownResult: .success(CovCABSBFFixtures.eraCountdown()))
    }

    private func amount(_ value: Decimal) -> String {
        balanceFactory.plainAmountFromValue(value, usageCase: .detailsCrypto).value(for: locale)
    }

    func testReturnsNilWithoutBalanceData() {
        XCTAssertNil(factory.buildViewModel(viewModelState: state, priceData: nil))
    }

    func testBuildsWidgetActionsAndUnbondingsWithPrice() throws {
        let ledger = try CovCABSBFFixtures.ledger(
            active: "3000000000000",
            unlocking: [("1000000000000", "99"), ("500000000000", "103"), ("500000000000", "102")]
        )
        feed(ledger: ledger)
        let price = PriceData(currencyId: "usd", priceId: "dot", price: "2", fiatDayChange: nil, coingeckoPriceId: nil)

        let resource = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: price))
        let viewModel = resource.value(for: locale)

        XCTAssertEqual(viewModel.title, R.string.localizable.stakingBalanceTitle(preferredLanguages: languages))
        XCTAssertEqual(viewModel.widgetViewModel.title, R.string.localizable.commonBalance(preferredLanguages: languages))
        let items = viewModel.widgetViewModel.itemViewModels
        XCTAssertEqual(items.map(\.title), [
            R.string.localizable.walletBalanceBonded(preferredLanguages: languages),
            R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: languages),
            R.string.localizable.walletBalanceRedeemable(preferredLanguages: languages)
        ])
        XCTAssertEqual(items.map(\.tokenAmountText), [amount(3), amount(1), amount(1)])
        XCTAssertEqual(items[0].usdAmountText, balanceFactory.priceFromAmount(3, priceData: price).value(for: locale))
        XCTAssertNotNil(items[1].usdAmountText)

        let actions = viewModel.actionsViewModel
        XCTAssertEqual(actions.bondTitle, StakingBalanceAction.bondMore.title(for: locale))
        XCTAssertEqual(actions.unbondTitle, StakingBalanceAction.unbond.title(for: locale))
        XCTAssertEqual(actions.redeemTitle, StakingBalanceAction.redeem.title(for: locale))
        XCTAssertTrue(actions.redeemActionIsAvailable)
        XCTAssertTrue(actions.stakeMoreActionAvailable)
        XCTAssertTrue(actions.stakeLessActionAvailable)

        let unbonding = viewModel.unbondingViewModel
        XCTAssertEqual(unbonding.title, R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: languages))
        XCTAssertEqual(
            unbonding.emptyListDescription,
            R.string.localizable.stakingUnbondingEmptyList_v190(preferredLanguages: languages)
        )
        XCTAssertEqual(unbonding.unbondings.count, 2)
        XCTAssertEqual(unbonding.unbondings.first?.addressOrName, R.string.localizable.stakingUnbond_v190(preferredLanguages: languages))
        XCTAssertEqual(unbonding.unbondings.first?.tokenAmountText, amount(0.5))
        XCTAssertNotNil(unbonding.unbondings.first?.usdAmountText)
        XCTAssertGreaterThan(unbonding.unbondings.first?.timeInterval ?? 0, 0)
        XCTAssertLessThan(unbonding.unbondings[0].timeInterval ?? 0, unbonding.unbondings[1].timeInterval ?? 0)
    }

    func testActionsDisabledWithoutRedeemablesAndNoPrice() throws {
        let ledger = try CovCABSBFFixtures.ledger(active: "2000000000000", unlocking: [])
        feed(ledger: ledger)

        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil)).value(for: locale)

        XCTAssertFalse(viewModel.actionsViewModel.redeemActionIsAvailable)
        XCTAssertTrue(viewModel.actionsViewModel.stakeLessActionAvailable)
        XCTAssertTrue(viewModel.unbondingViewModel.unbondings.isEmpty)
        XCTAssertTrue(viewModel.widgetViewModel.itemViewModels.allSatisfy { $0.usdAmountText == nil })
        XCTAssertEqual(viewModel.widgetViewModel.itemViewModels.first?.tokenAmountText, amount(2))
    }

    func testStakeLessUnavailableWhenAllBondedIsRedeemable() throws {
        let ledger = try CovCABSBFFixtures.ledger(active: "1000000000000", unlocking: [("1000000000000", "90")])
        feed(ledger: ledger)

        let viewModel = try XCTUnwrap(factory.buildViewModel(viewModelState: state, priceData: nil)).value(for: locale)

        XCTAssertTrue(viewModel.actionsViewModel.redeemActionIsAvailable)
        XCTAssertFalse(viewModel.actionsViewModel.stakeLessActionAvailable)
    }

    func testHelperBuildersProduceItems() throws {
        let item = factory.createWidgetItemViewModel(amount: 4, title: "T", priceData: nil, locale: locale)
        XCTAssertEqual(item.title, "T")
        XCTAssertEqual(item.tokenAmountText, amount(4))
        XCTAssertNil(item.usdAmountText)

        let actions = factory.createActionsViewModel(redeemableDecimal: 0, bondedDecimal: 0, locale: locale)
        XCTAssertFalse(actions.redeemActionIsAvailable)
        XCTAssertFalse(actions.stakeLessActionAvailable)
        XCTAssertNotNil(actions.redeemIcon)

        let ledger = try CovCABSBFFixtures.ledger(active: "1", unlocking: [("1000000000000", "105")])
        let data = StakingBalanceData(stakingLedger: ledger, activeEra: 100, eraCountdown: nil)
        let unbondings = factory.createUnbondingsViewModels(from: data, priceData: nil, precision: 12, locale: locale)
        XCTAssertEqual(unbondings.count, 1)
        XCTAssertEqual(unbondings.first?.timeInterval, 0)
    }
}
