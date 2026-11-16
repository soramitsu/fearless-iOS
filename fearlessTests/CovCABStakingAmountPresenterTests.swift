import XCTest
import SSFModels
import SoraFoundation
import BigInt
import RobinHood
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

enum CovCABSAPError: Error {
    case failed
}

final class CovCABSAPRuntime: RuntimeProviderProtocol {
    var snapshot: RuntimeSnapshot? { nil }
    var runtimeSpecVersion: RuntimeSpecVersion { .defaultVersion }

    func setup() {}
    func cleanup() {}
    func setupHot() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw CovCABSAPError.failed
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let operation = BaseOperation<RuntimeCoderFactoryProtocol>()
        operation.result = .failure(CovCABSAPError.failed)
        return operation
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovCABSAPError.failed
    }
}

final class CovCABSAPView: UIViewController, StakingAmountViewProtocol {
    private(set) var mainViewModels: [StakingAmountMainViewModel] = []
    private(set) var rewardDestinations: [LocalizableResource<RewardDestinationViewModelProtocol>] = []
    private(set) var assets: [LocalizableResource<AssetBalanceViewModelProtocol>] = []
    private(set) var fees: [LocalizableResource<BalanceViewModelProtocol>?] = []
    private(set) var inputs: [LocalizableResource<IAmountInputViewModel>] = []
    private(set) var startLoadingCalls = 0
    private(set) var stopLoadingCalls = 0
    private(set) var presentedControllers: [UIViewController] = []

    func didReceive(viewModel: StakingAmountMainViewModel) {
        mainViewModels.append(viewModel)
    }

    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>) {
        rewardDestinations.append(viewModel)
    }

    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        assets.append(viewModel)
    }

    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        fees.append(viewModel)
    }

    func didReceiveInput(viewModel: LocalizableResource<IAmountInputViewModel>) {
        inputs.append(viewModel)
    }

    func applyLocalization() {}

    func didStartLoading() {
        startLoadingCalls += 1
    }

    func didStopLoading() {
        stopLoadingCalls += 1
    }

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCABSAPWireframe: StakingAmountWireframeProtocol {
    private(set) var selections: [(accounts: [fearless.ChainAccountResponse], selected: fearless.ChainAccountResponse)] = []
    private(set) var proceededStates: [InitiatedBonding] = []
    private(set) var closeCalls = 0
    private(set) var webURLs: [URL] = []
    private(set) var errors: [Error] = []
    private(set) var amountTooHighCalls = 0
    private(set) var sheetViewModels: [SheetAlertPresentableViewModel] = []
    var presentErrorResult = false

    func presentAccountSelection(
        _ accounts: [fearless.ChainAccountResponse],
        selectedAccountItem: fearless.ChainAccountResponse,
        delegate _: ModalPickerViewControllerDelegate,
        from _: StakingAmountViewProtocol?,
        context _: AnyObject?
    ) {
        selections.append((accounts, selectedAccountItem))
    }

    func proceed(
        from _: StakingAmountViewProtocol?,
        state: InitiatedBonding,
        asset _: AssetModel,
        chain _: ChainModel,
        selectedAccount _: fearless.MetaAccountModel
    ) {
        proceededStates.append(state)
    }

    func close(view _: StakingAmountViewProtocol?) {
        closeCalls += 1
    }

    func showWeb(url: URL, from _: ControllerBackedProtocol, style _: WebPresentableStyle) {
        webURLs.append(url)
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return presentErrorResult
    }

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {
        amountTooHighCalls += 1
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheetViewModels.append(viewModel)
    }
}

final class CovCABSAPInteractor: StakingAmountInteractorInputProtocol {
    private(set) var setupCalls = 0
    private(set) var estimateFeeCalls = 0
    private(set) var fetchAccountsCalls = 0

    func setup() {
        setupCalls += 1
    }

    func estimateFee(extrinsicBuilderClosure _: @escaping ExtrinsicBuilderClosure) {
        estimateFeeCalls += 1
    }

    func fetchAccounts() {
        fetchAccountsCalls += 1
    }
}

final class CovCABSAPScheduler: fearless.SchedulerProtocol {
    func notifyAfter(_: TimeInterval) {}
    func cancel() {}
}

final class CovCABSAPCalculator: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal { 1 }

    func calculateEarnings(amount _: Decimal, validatorAccountId _: AccountId, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal {
        0
    }

    func calculateMaxEarnings(amount _: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { 0 }
    func calculateAvgEarnings(amount _: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { 0 }
    func calculatorReturn(isCompound _: Bool, period _: CalculationPeriod, type _: RewardReturnType) -> Decimal { 0.1 }
    func maxEarningsTitle(locale _: Locale) -> String { "" }
    func avgEarningTitle(locale _: Locale) -> String { "" }
}

final class CovCABStakingAmountPresenterTests: XCTestCase {
    private var view: CovCABSAPView!
    private var wireframe: CovCABSAPWireframe!
    private var interactor: CovCABSAPInteractor!
    private var state: StakingAmountRelaychainViewModelState!
    private var presenter: StakingAmountPresenter!
    private var wallet: fearless.MetaAccountModel!
    private var chain: ChainModel!

    override func setUp() {
        super.setUp()
        chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        wallet = AccountGenerator.generateMetaAccount()

        view = CovCABSAPView()
        view.localizationManager = LocalizationManager(localization: "en")
        wireframe = CovCABSAPWireframe()
        interactor = CovCABSAPInteractor()

        let balanceFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
        let validating = StakingDataValidatingFactory(presentable: wireframe, balanceFactory: balanceFactory)
        validating.view = view
        let rewardFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceFactory,
            iconGenerator: UniversalIconGenerator(),
            chainAsset: chainAsset
        )
        state = StakingAmountRelaychainViewModelState(
            dataValidatingFactory: validating,
            wallet: wallet,
            chainAsset: chainAsset,
            amount: nil,
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovCABSAPRuntime()),
            rewardChainAsset: nil
        )
        let viewModelFactory = StakingAmountRelaychainViewModelFactory(
            balanceViewModelFactory: balanceFactory,
            rewardDestViewModelFactory: rewardFactory,
            chainAsset: chainAsset,
            wallet: wallet
        )
        presenter = StakingAmountPresenter(
            asset: asset,
            chain: chain,
            selectedAccount: wallet,
            rewardDestViewModelFactory: rewardFactory,
            balanceViewModelFactory: balanceFactory,
            dataValidatingFactory: validating,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared,
            viewModelState: state,
            viewModelFactory: viewModelFactory
        )
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
    }

    override func tearDown() {
        presenter = nil
        state = nil
        interactor = nil
        wireframe = nil
        view = nil
        wallet = nil
        chain = nil
        super.tearDown()
    }

    private func balanceData(free: BigUInt) -> AccountData {
        AccountData(free: free, reserved: 0, frozen: 0, flags: 0)
    }

    func testSetupProvidesInputDestinationAndEstimatesFee() throws {
        presenter.setup()

        XCTAssertTrue(state.stateListener === presenter)
        XCTAssertEqual(view.inputs.count, 1)
        XCTAssertEqual(view.rewardDestinations.count, 1)
        XCTAssertEqual(interactor.setupCalls, 1)
        XCTAssertEqual(interactor.estimateFeeCalls, 1)
        XCTAssertEqual(view.startLoadingCalls, 1)
        XCTAssertEqual(view.inputs.first?.value(for: Locale(identifier: "en")).symbol, "DOT")
    }

    func testDestinationSelectionRebuildsViewModel() throws {
        presenter.setup()

        presenter.selectPayoutDestination()
        XCTAssertEqual(view.mainViewModels.count, 1)
        XCTAssertEqual(interactor.estimateFeeCalls, 2)
        let payoutType = try XCTUnwrap(view.mainViewModels.last?.rewardDestinationViewModel).value(for: Locale(identifier: "en")).type
        guard case .payout = payoutType else {
            return XCTFail("expected payout")
        }

        presenter.selectRestakeDestination()
        XCTAssertEqual(view.mainViewModels.count, 2)
        XCTAssertEqual(interactor.estimateFeeCalls, 3)
        XCTAssertGreaterThanOrEqual(view.stopLoadingCalls, 2)
    }

    func testAmountPercentageRequiresBalanceAndFee() {
        presenter.setup()
        presenter.selectAmountPercentage(0.5)
        XCTAssertEqual(view.inputs.count, 1)

        presenter.didReceive(balance: balanceData(free: BigUInt(100_000_000_000)))
        XCTAssertEqual(view.assets.count, 1)
        state.fee = 1

        presenter.selectAmountPercentage(0.5)

        XCTAssertEqual(view.inputs.count, 2)
        XCTAssertEqual(view.assets.count, 2)
        XCTAssertEqual(state.amount, Decimal(string: "4.5"))
        XCTAssertEqual(wireframe.amountTooHighCalls, 0)
    }

    func testAmountPercentageWithoutFundsShowsAmountTooHigh() {
        presenter.didReceive(balance: nil)
        state.fee = 1

        presenter.selectAmountPercentage(1)

        XCTAssertEqual(wireframe.amountTooHighCalls, 1)
        XCTAssertEqual(view.assets.count, 1)
    }

    func testPayoutAccountSelectionFlow() throws {
        let account = try XCTUnwrap(state.payoutAccount)

        presenter.selectPayoutAccount()
        presenter.selectPayoutAccount()
        XCTAssertEqual(interactor.fetchAccountsCalls, 1)

        presenter.didReceive(accounts: [account])
        XCTAssertEqual(wireframe.selections.count, 1)
        XCTAssertEqual(wireframe.selections.first?.selected, account)

        presenter.selectPayoutAccount()
        XCTAssertEqual(interactor.fetchAccountsCalls, 2)
    }

    func testPickerSelectionUpdatesPayoutAccount() throws {
        presenter.setup()
        let other = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest()))

        presenter.modalPickerDidSelectModelAtIndex(0, context: PrimitiveContextWrapper(value: [other]))
        XCTAssertEqual(state.payoutAccount, other)
        XCTAssertEqual(view.mainViewModels.count, 1)

        presenter.modalPickerDidSelectModelAtIndex(0, context: nil)
        XCTAssertEqual(view.mainViewModels.count, 1)
    }

    func testLearnMoreAndClose() {
        presenter.selectLearnMore()
        presenter.close()

        XCTAssertEqual(wireframe.webURLs, [ApplicationConfig.shared.learnPayoutURL])
        XCTAssertEqual(wireframe.closeCalls, 1)
    }

    func testUpdateAmountProvidesAssetAndEstimatesFee() {
        presenter.updateAmount(3)

        XCTAssertEqual(state.amount, 3)
        XCTAssertEqual(view.assets.count, 1)
        XCTAssertEqual(view.rewardDestinations.count, 1)
        XCTAssertEqual(interactor.estimateFeeCalls, 1)

        presenter.didTrigger(scheduler: CovCABSAPScheduler())
        XCTAssertEqual(interactor.estimateFeeCalls, 2)
    }

    func testProceedWithoutFeeRequestsFeeAgain() {
        presenter.updateAmount(2)
        let before = interactor.estimateFeeCalls

        presenter.proceed()

        XCTAssertTrue(wireframe.proceededStates.isEmpty)
        XCTAssertEqual(interactor.estimateFeeCalls, before + 1)
        XCTAssertTrue(view.presentedControllers.last is SheetAletViewController)
    }

    func testProceedWithValidDataOpensValidatorSelection() {
        presenter.didReceive(balance: balanceData(free: BigUInt(100_000_000_000)))
        state.didReceive(minimalBalance: BigUInt(1_000_000_000))
        state.didReceive(paymentInfo: RuntimeDispatchInfo(feeValue: BigUInt(10_000_000_000)))
        presenter.updateAmount(2)

        presenter.proceed()

        XCTAssertEqual(wireframe.proceededStates.count, 1)
        XCTAssertEqual(wireframe.proceededStates.first?.amount, 2)
    }

    func testErrorsAreForwardedToWireframe() {
        presenter.didReceive(error: CovCABSAPError.failed)
        wireframe.presentErrorResult = true
        presenter.didReceive(calculatorError: CovCABSAPError.failed)

        XCTAssertEqual(wireframe.errors.count, 2)
    }

    func testCalculatorProducesRewardValues() throws {
        presenter.updateAmount(10)
        presenter.didReceive(calculator: CovCABSAPCalculator())

        let destination = try XCTUnwrap(view.rewardDestinations.last).value(for: Locale(identifier: "en"))
        XCTAssertNotNil(destination.rewardViewModel)
        XCTAssertEqual(view.rewardDestinations.count, 2)
    }

    func testPresenterWithoutStateDoesNothing() {
        let asset = ChainModelGenerator.generateAssetWithId("ksm", symbol: "KSM", assetPresicion: 12)
        let balanceFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
        let bare = StakingAmountPresenter(
            asset: asset,
            chain: chain,
            selectedAccount: wallet,
            rewardDestViewModelFactory: RewardDestinationViewModelFactory(
                balanceViewModelFactory: balanceFactory,
                iconGenerator: UniversalIconGenerator(),
                chainAsset: ChainAsset(chain: chain, asset: asset)
            ),
            balanceViewModelFactory: balanceFactory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared,
            viewModelState: nil,
            viewModelFactory: nil
        )
        bare.view = view
        bare.wireframe = wireframe
        bare.interactor = interactor

        bare.setup()
        bare.selectLearnMore()
        bare.didReceive(accounts: [])

        XCTAssertEqual(interactor.setupCalls, 1)
        XCTAssertEqual(interactor.estimateFeeCalls, 0)
        XCTAssertTrue(view.rewardDestinations.isEmpty)
        XCTAssertEqual(view.inputs.count, 1)
        XCTAssertTrue(wireframe.webURLs.isEmpty)
        XCTAssertTrue(wireframe.selections.isEmpty)
    }
}
