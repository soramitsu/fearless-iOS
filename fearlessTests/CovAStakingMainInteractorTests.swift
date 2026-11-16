import BigInt
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovAStakingMainInteractorOutputSpy: StakingMainInteractorOutputProtocol {
    private let lock = NSLock()
    private var storedEvents: [String] = []

    var events: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    private func record(_ event: String) {
        lock.lock()
        defer { lock.unlock() }
        storedEvents.append(event)
    }

    func count(_ event: String) -> Int {
        events.filter { $0 == event }.count
    }

    func didReceive(selectedWallet _: MetaAccountModel) {
        record("wallet")
    }

    func didReceive(selectedAddress _: String) {
        record("address")
    }

    func didReceive(totalReward _: TotalRewardItem) {
        record("totalReward")
    }

    func didReceive(totalReward _: Error) {
        record("totalRewardError")
    }

    func didReceive(accountInfo _: AccountInfo?) {
        record("accountInfo")
    }

    func didReceive(balanceError _: Error) {
        record("balanceError")
    }

    func didReceive(calculator _: RewardCalculatorEngineProtocol) {
        record("calculator")
    }

    func didReceive(calculatorError _: Error) {
        record("calculatorError")
    }

    func didReceive(stashItem _: StashItem?) {
        record("stash")
    }

    func didReceive(stashItemError _: Error) {
        record("stashError")
    }

    func didReceive(ledgerInfo _: StakingLedger?) {
        record("ledger")
    }

    func didReceive(ledgerInfoError _: Error) {
        record("ledgerError")
    }

    func didReceive(nomination _: Nomination?) {
        record("nomination")
    }

    func didReceive(nominationError _: Error) {
        record("nominationError")
    }

    func didReceive(validatorPrefs _: ValidatorPrefs?) {
        record("validator")
    }

    func didReceive(validatorError _: Error) {
        record("validatorError")
    }

    func didReceive(eraStakersInfo _: EraStakersInfo) {
        record("eraStakers")
    }

    func didReceive(eraStakersInfoError _: Error) {
        record("eraStakersError")
    }

    func didReceive(networkStakingInfo _: NetworkStakingInfo) {
        record("networkInfo")
    }

    func didReceive(networkStakingInfoError _: Error) {
        record("networkInfoError")
    }

    func didReceive(payee _: RewardDestinationArg?) {
        record("payee")
    }

    func didReceive(payeeError _: Error) {
        record("payeeError")
    }

    func didReceive(newChainAsset _: ChainAsset?) {
        record("chainAsset")
    }

    func didReceieve(subqueryRewards _: Result<[SubqueryRewardItemData]?, Error>, period _: AnalyticsPeriod) {
        record("subquery")
    }

    func didReceiveMinNominatorBond(result _: Result<BigUInt?, Error>) {
        record("minBond")
    }

    func didReceiveCounterForNominators(result _: Result<UInt32?, Error>) {
        record("counter")
    }

    func didReceiveMaxNominatorsCount(result _: Result<UInt32?, Error>) {
        record("maxCount")
    }

    func didReceive(eraCountdownResult _: Result<EraCountdown, Error>) {
        record("countdown")
    }

    func didReceive(rewardChainAsset _: ChainAsset?) {
        record("rewardChainAsset")
    }

    func didReceiveMaxNominatorsPerValidator(_: UInt32?) {
        record("maxPerValidator")
    }

    func didReceiveControllerAccount(result _: Result<ChainAccountResponse?, Error>) {
        record("controller")
    }

    func networkInfoViewExpansion(isExpanded _: Bool) {
        record("expansion")
    }
}

final class CovAChainAssetFetchingStub: ChainAssetFetchingProtocol {
    var chainAssets: [ChainAsset] = []

    func fetch(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        completionBlock(.success(chainAssets))
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        let assets = chainAssets
        return ClosureOperation { assets }
    }

    func fetchAwait(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        chainAssets
    }
}

final class CovAStakingMainInteractorTests: XCTestCase {
    private typealias CovAFixtureAlias = CovAStakingMainFixtures

    private struct CovAContext {
        let interactor: StakingMainInteractor
        let output: CovAStakingMainInteractorOutputSpy
        let adapter: CovAAccountInfoAdapterStub
        let settings: InMemorySettingsManager
    }

    private func makeContext() throws -> CovAContext {
        let wallet = CovAFixtures.wallet()
        let walletSettings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        walletSettings.internalValue = wallet
        let stakingSettings = StakingAssetSettings(
            storageFacade: SubstrateStorageTestFacade(),
            settings: InMemorySettingsManager(),
            operationQueue: OperationQueue(),
            wallet: wallet
        )
        stakingSettings.internalValue = CovAFixtures.chainAsset()
        let calculator = RewardCalculatorServiceStub(engine: CovARewardCalculatorStub())
        let eraValidators = try EraValidatorServiceStub(info: CovAFixtureAlias.eraStakers())
        let sharedState = StakingSharedState(
            settings: stakingSettings,
            eraValidatorService: eraValidators,
            rewardCalculationService: calculator,
            relaychainStakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryStub(
                minNominatorBond: 5, counterForNominators: 1, maxNominatorsCount: 10,
                stashItem: CovAFixtureAlias.stash()
            )
        )
        let adapter = CovAAccountInfoAdapterStub()
        let settings = InMemorySettingsManager()
        let interactor = StakingMainInteractor(
            selectedWalletSettings: walletSettings,
            sharedState: sharedState,
            chainRegistry: ChainRegistryProtocolStub(),
            stakingRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocolStub(),
            stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocolStub(),
            accountInfoSubscriptionAdapter: adapter,
            stakingServiceFactory: MockStakingServiceFactoryProtocol().apply(
                eraValidatorService: eraValidators,
                rewardCalculatorService: calculator
            ),
            accountProviderFactory: AccountProviderFactory(storageFacade: UserDataStorageTestFacade(), operationManager: OperationManager()),
            eventCenter: EventCenter(),
            operationManager: OperationManager(),
            applicationHandler: ApplicationHandler(),
            eraCountdownOperationFactory: EraCountdownOperationFactoryStub(eraCountdown: .testStub),
            commonSettings: settings,
            logger: Logger.shared,
            chainAssetFetching: CovAChainAssetFetchingStub()
        )
        let output = CovAStakingMainInteractorOutputSpy()
        interactor.presenter = output
        return CovAContext(interactor: interactor, output: output, adapter: adapter, settings: settings)
    }

    func testSetupProvidesChainAccountAndExpansion() throws {
        let context = try makeContext()
        context.interactor.setup()
        XCTAssertEqual(context.interactor.selectedChainAsset?.chain.chainId, CovAFixtures.chainId)
        XCTAssertNotNil(context.interactor.selectedAccount)
        XCTAssertTrue(context.output.events.contains("chainAsset"))
        XCTAssertTrue(context.output.events.contains("address"))

        context.interactor.saveNetworkInfoViewExpansion(isExpanded: true)
        XCTAssertTrue(context.settings.stakingNetworkExpansion)
        context.interactor.changeActiveState(true)
        context.interactor.changeActiveState(false)
        XCTAssertFalse(context.interactor.isActive)
    }

    func testProvidersAndHandlersForwardResults() throws {
        let context = try makeContext()
        context.interactor.setupSelectedAccountAndChainAsset()
        let interactor = context.interactor
        interactor.provideRewardCalculator(from: RewardCalculatorServiceStub(engine: CovARewardCalculatorStub()))
        try interactor.provideEraStakersInfo(from: EraValidatorServiceStub(info: CovAFixtureAlias.eraStakers()))
        interactor.provideMaxNominatorsPerValidator(from: CovARuntimeCodingServiceStub())
        interactor.provideNewChain()
        interactor.provideSelectedAccount()
        interactor.provideRewardChainAsset()
        interactor.fetchEraCompletionTime()
        interactor.performAccountInfoSubscription()
        interactor.performStashControllerSubscription()
        interactor.performNominatorLimitsSubscripion()

        interactor.handleStashItem(result: .success(CovAFixtureAlias.stash()), for: CovAFixtureAlias.stashAddress)
        interactor.handleStashItem(result: .failure(CovATestError.failed), for: CovAFixtureAlias.stashAddress)
        try interactor.handleLedgerInfo(result: .success(CovAFixtureAlias.ledger()), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        interactor.handleLedgerInfo(result: .failure(CovATestError.failed), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        try interactor.handleNomination(result: .success(CovAFixtureAlias.nomination()), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        interactor.handleNomination(result: .failure(CovATestError.failed), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        interactor.handleValidator(result: .success(CovAFixtureAlias.prefs()), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        interactor.handleValidator(result: .failure(CovATestError.failed), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        interactor.handlePayee(result: .success(.staked), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        interactor.handlePayee(result: .failure(CovATestError.failed), accountId: CovAFixtures.accountId(7), chainId: CovAFixtures.chainId)
        interactor.handleMinNominatorBond(result: .success(5), chainId: CovAFixtures.chainId)
        interactor.handleCounterForNominators(result: .success(1), chainId: CovAFixtures.chainId)
        interactor.handleMaxNominatorsCount(result: .success(10), chainId: CovAFixtures.chainId)
        interactor.handleAccountInfo(result: .success(nil), accountId: CovAFixtures.accountId(7), chainAsset: CovAFixtures.chainAsset())
        interactor.handleAccountInfo(result: .failure(CovATestError.failed), accountId: CovAFixtures.accountId(7), chainAsset: CovAFixtures.chainAsset())

        CovAViewInspector.spin(until: {
            context.output.count("calculator") >= 1 && context.output.count("eraStakers") >= 1
                && context.output.count("maxPerValidator") >= 1
        })
        let events = context.output.events
        for expected in ["calculator", "eraStakers", "stash", "stashError", "ledger", "ledgerError", "nomination",
                         "nominationError", "validator", "validatorError", "payee", "payeeError", "minBond", "counter",
                         "maxCount", "accountInfo", "balanceError", "maxPerValidator", "countdown"] {
            XCTAssertTrue(events.contains(expected), "\(expected) missing from \(events)")
        }
        XCTAssertGreaterThanOrEqual(context.adapter.subscribedChainAssets.count, 1)
        interactor.clearStashControllerSubscription()
        interactor.clearNominatorsLimitProviders()
        interactor.clearAccountRemoteSubscription()
    }

    func testEventsAndChainChanges() throws {
        let context = try makeContext()
        context.interactor.setup()
        context.interactor.changeActiveState(true)
        context.interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: CovAFixtures.wallet()))
        context.interactor.processEraStakersInfoChanged(event: EraStakersInfoChanged())
        context.interactor.updatePrices()
        context.interactor.save(chainAsset: CovAFixtures.chainAsset(chainId: "cov-a-second"))
        CovAViewInspector.spin(until: { context.output.count("chainAsset") >= 2 }, timeout: 3)
        XCTAssertGreaterThanOrEqual(context.output.count("chainAsset"), 2)
        XCTAssertTrue(context.output.events.contains("wallet"))
        context.interactor.updateSharedState()
    }
}
